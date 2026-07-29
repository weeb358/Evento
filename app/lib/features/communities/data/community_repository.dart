import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import 'community.dart';

class CommunityRepository {
  CommunityRepository(this._client);

  final SupabaseClient _client;

  Future<Result<List<Community>>> browseCommunities({String? search}) {
    return guard(() async {
      var query = _client.from('communities').select();
      if ((search ?? '').trim().isNotEmpty) {
        query = query.ilike('name', '%${search!.trim()}%');
      }
      final rows = await query.order('created_at', ascending: false).limit(50);
      return rows.map(Community.fromJson).toList();
    });
  }

  Future<Result<List<Community>>> getMyCommunities(String userId) {
    return guard(() async {
      final memberships = await _client.from('community_members').select('community_id').eq('user_id', userId);
      final ids = memberships.map((m) => m['community_id'] as String).toList();
      if (ids.isEmpty) return <Community>[];
      final rows = await _client.from('communities').select().inFilter('id', ids);
      return rows.map(Community.fromJson).toList();
    });
  }

  Future<Result<Community?>> getCommunity(String id) {
    return guard(() async {
      final row = await _client.from('communities').select().eq('id', id).maybeSingle();
      return row == null ? null : Community.fromJson(row);
    });
  }

  Future<Result<Community>> createCommunity({
    required String name,
    required String slug,
    required String createdBy,
    String? description,
    bool isPrivate = false,
  }) {
    return guard(() async {
      final row = await _client
          .from('communities')
          .insert({
            'name': name,
            'slug': slug,
            'description': description,
            'is_private': isPrivate,
            'created_by': createdBy,
          })
          .select()
          .single();
      return Community.fromJson(row);
    });
  }

  Future<Result<String>> uploadCoverImage({required String communityId, required Uint8List bytes, required String fileExt}) {
    return guard(() async {
      final path = '$communityId/cover.$fileExt';
      await _client.storage.from('community-covers').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _client.storage.from('community-covers').getPublicUrl(path);
      await _client.from('communities').update({'cover_image_url': url}).eq('id', communityId);
      return url;
    });
  }

  Future<Result<CommunityMember?>> getMembership({required String communityId, required String userId}) {
    return guard(() async {
      final row = await _client
          .from('community_members')
          .select()
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .maybeSingle();
      return row == null ? null : CommunityMember.fromJson(row);
    });
  }

  Future<Result<List<CommunityMember>>> getMembers(String communityId) {
    return guard(() async {
      final rows = await _client
          .from('community_members')
          .select()
          .eq('community_id', communityId)
          .order('joined_at');
      return rows.map(CommunityMember.fromJson).toList();
    });
  }

  Future<Result<void>> join({required String communityId, required String userId}) {
    return guard(() async {
      await _client.from('community_members').insert({'community_id': communityId, 'user_id': userId});
    });
  }

  Future<Result<void>> leave({required String communityId, required String userId}) {
    return guard(() async {
      await _client.from('community_members').delete().eq('community_id', communityId).eq('user_id', userId);
    });
  }

  Future<Result<void>> setMemberRole({
    required String communityId,
    required String userId,
    required CommunityMemberRole role,
  }) {
    return guard(() async {
      await _client
          .from('community_members')
          .update({'role': role.name})
          .eq('community_id', communityId)
          .eq('user_id', userId);
    });
  }

  Future<Result<List<CommunityPost>>> getPosts(String communityId) {
    return guard(() async {
      final rows = await _client
          .from('community_posts')
          .select()
          .eq('community_id', communityId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);
      return rows.map(CommunityPost.fromJson).toList();
    });
  }

  Future<Result<CommunityPost>> createPost({
    required String communityId,
    required String authorId,
    required String content,
    String? imageUrl,
  }) {
    return guard(() async {
      final row = await _client
          .from('community_posts')
          .insert({
            'community_id': communityId,
            'author_id': authorId,
            'content': content,
            'image_url': imageUrl,
          })
          .select()
          .single();
      return CommunityPost.fromJson(row);
    });
  }

  Future<Result<void>> setPostPinned({required String postId, required bool isPinned}) {
    return guard(() async {
      await _client.from('community_posts').update({'is_pinned': isPinned}).eq('id', postId);
    });
  }

  Future<Result<void>> deletePost(String postId) {
    return guard(() => _client.from('community_posts').delete().eq('id', postId));
  }

  Future<Result<List<PostComment>>> getComments(String postId) {
    return guard(() async {
      final rows = await _client.from('post_comments').select().eq('post_id', postId).order('created_at');
      return rows.map(PostComment.fromJson).toList();
    });
  }

  Future<Result<PostComment>> addComment({
    required String postId,
    required String authorId,
    required String content,
  }) {
    return guard(() async {
      final row = await _client
          .from('post_comments')
          .insert({'post_id': postId, 'author_id': authorId, 'content': content})
          .select()
          .single();
      return PostComment.fromJson(row);
    });
  }

  Future<Result<Set<String>>> getLikedPostIds({required List<String> postIds, required String userId}) {
    return guard(() async {
      if (postIds.isEmpty) return <String>{};
      final rows = await _client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      return rows.map((r) => r['post_id'] as String).toSet();
    });
  }

  Future<Result<int>> getLikeCount(String postId) {
    return guard(() async {
      final rows = await _client.from('post_likes').select('id').eq('post_id', postId);
      return rows.length;
    });
  }

  Future<Result<bool>> toggleLike({required String postId, required String userId}) {
    return guard(() async {
      final existing = await _client
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      if (existing == null) {
        await _client.from('post_likes').insert({'post_id': postId, 'user_id': userId});
        return true;
      } else {
        await _client.from('post_likes').delete().eq('id', existing['id'] as String);
        return false;
      }
    });
  }
}
