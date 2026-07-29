import 'package:equatable/equatable.dart';

class Community extends Equatable {
  const Community({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.coverImageUrl,
    this.rules,
    required this.isPrivate,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? coverImageUrl;
  final String? rules;
  final bool isPrivate;
  final String createdBy;
  final DateTime createdAt;

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      rules: json['rules'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, slug, description, coverImageUrl, rules, isPrivate, createdBy, createdAt];
}

enum CommunityMemberRole { owner, moderator, member }

CommunityMemberRole communityMemberRoleFromString(String value) {
  return CommunityMemberRole.values.firstWhere((r) => r.name == value, orElse: () => CommunityMemberRole.member);
}

class CommunityMember extends Equatable {
  const CommunityMember({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  final String id;
  final String communityId;
  final String userId;
  final CommunityMemberRole role;
  final DateTime joinedAt;

  bool get isModerator => role == CommunityMemberRole.owner || role == CommunityMemberRole.moderator;

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    return CommunityMember(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      userId: json['user_id'] as String,
      role: communityMemberRoleFromString(json['role'] as String? ?? 'member'),
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, communityId, userId, role, joinedAt];
}

class CommunityPost extends Equatable {
  const CommunityPost({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.content,
    this.imageUrl,
    required this.isPinned,
    required this.createdAt,
  });

  final String id;
  final String communityId;
  final String authorId;
  final String content;
  final String? imageUrl;
  final bool isPinned;
  final DateTime createdAt;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, communityId, authorId, content, imageUrl, isPinned, createdAt];
}

class PostComment extends Equatable {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, postId, authorId, content, createdAt];
}
