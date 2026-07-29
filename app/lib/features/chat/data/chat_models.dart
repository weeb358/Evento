import 'package:equatable/equatable.dart';

class ChatThread extends Equatable {
  const ChatThread({
    required this.id,
    required this.isGroup,
    this.communityId,
    this.title,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final bool isGroup;
  final String? communityId;
  final String? title;
  final String createdBy;
  final DateTime createdAt;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      isGroup: json['is_group'] as bool? ?? false,
      communityId: json['community_id'] as String?,
      title: json['title'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, isGroup, communityId, title, createdBy, createdAt];
}

class ChatParticipant extends Equatable {
  const ChatParticipant({
    required this.id,
    required this.threadId,
    required this.userId,
    required this.joinedAt,
    this.lastReadAt,
  });

  final String id;
  final String threadId;
  final String userId;
  final DateTime joinedAt;
  final DateTime? lastReadAt;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      lastReadAt: json['last_read_at'] != null ? DateTime.parse(json['last_read_at'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [id, threadId, userId, joinedAt, lastReadAt];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    this.content,
    this.imageUrl,
    this.locationLat,
    this.locationLng,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String? content;
  final String? imageUrl;
  final double? locationLat;
  final double? locationLng;
  final DateTime createdAt;

  bool get hasLocation => locationLat != null && locationLng != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, threadId, senderId, content, imageUrl, locationLat, locationLng, createdAt];
}
