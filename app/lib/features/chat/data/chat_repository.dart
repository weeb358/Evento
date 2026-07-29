import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import 'chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  /// My threads, newest-activity first — a thread with no messages yet
  /// sorts by its own created_at.
  Future<Result<List<ChatThread>>> getMyThreads(String userId) {
    return guard(() async {
      final participantRows = await _client.from('chat_participants').select('thread_id').eq('user_id', userId);
      final threadIds = participantRows.map((r) => r['thread_id'] as String).toList();
      if (threadIds.isEmpty) return <ChatThread>[];

      final rows = await _client
          .from('chat_threads')
          .select()
          .inFilter('id', threadIds)
          .order('created_at', ascending: false);
      return rows.map(ChatThread.fromJson).toList();
    });
  }

  Future<Result<List<ChatParticipant>>> getParticipants(String threadId) {
    return guard(() async {
      final rows = await _client.from('chat_participants').select().eq('thread_id', threadId);
      return rows.map(ChatParticipant.fromJson).toList();
    });
  }

  /// See get_or_create_direct_thread() in 0009_communities_and_chat.sql —
  /// avoids duplicate DM threads between the same pair of users.
  Future<Result<String>> getOrCreateDirectThread(String otherUserId) {
    return guard(() async {
      final threadId = await _client.rpc('get_or_create_direct_thread', params: {'other_user_id': otherUserId});
      return threadId as String;
    });
  }

  Future<Result<ChatThread>> createGroupThread({
    required String createdBy,
    required String title,
    required List<String> memberUserIds,
    String? communityId,
  }) {
    return guard(() async {
      final row = await _client
          .from('chat_threads')
          .insert({
            'is_group': true,
            'title': title,
            'created_by': createdBy,
            'community_id': communityId,
          })
          .select()
          .single();
      final thread = ChatThread.fromJson(row);

      final allMembers = {createdBy, ...memberUserIds};
      await _client
          .from('chat_participants')
          .insert(allMembers.map((userId) => {'thread_id': thread.id, 'user_id': userId}).toList());

      return thread;
    });
  }

  Future<Result<List<ChatMessage>>> getMessages(String threadId) {
    return guard(() async {
      final rows = await _client
          .from('chat_messages')
          .select()
          .eq('thread_id', threadId)
          .order('created_at');
      return rows.map(ChatMessage.fromJson).toList();
    });
  }

  Future<Result<void>> sendMessage({
    required String threadId,
    required String senderId,
    String? content,
    String? imageUrl,
    double? locationLat,
    double? locationLng,
  }) {
    return guard(() async {
      await _client.from('chat_messages').insert({
        'thread_id': threadId,
        'sender_id': senderId,
        'content': content,
        'image_url': imageUrl,
        'location_lat': locationLat,
        'location_lng': locationLng,
      });
    });
  }

  Future<Result<String>> uploadImage({required String threadId, required Uint8List bytes, required String fileExt}) {
    return guard(() async {
      final path = '$threadId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await _client.storage.from('chat-images').uploadBinary(path, bytes);
      return _client.storage.from('chat-images').getPublicUrl(path);
    });
  }

  Future<Result<void>> markRead({required String threadId, required String userId}) {
    return guard(() async {
      await _client
          .from('chat_participants')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    });
  }

  /// Live message stream for a thread — Postgres changes via Realtime
  /// (chat_messages is in the `supabase_realtime` publication, see 0009).
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessage.fromJson).toList());
  }

  /// Typing indicators never touch Postgres — a Broadcast channel per
  /// thread, ephemeral by design.
  RealtimeChannel typingChannel(String threadId) {
    return _client.channel('typing:$threadId');
  }

  Future<void> broadcastTyping({
    required RealtimeChannel channel,
    required String userId,
    required bool isTyping,
  }) async {
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': userId, 'is_typing': isTyping},
    );
  }
}
