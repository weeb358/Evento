import 'package:equatable/equatable.dart';

enum UserTier { standard, premium }

UserTier userTierFromString(String value) =>
    value == 'premium' ? UserTier.premium : UserTier.standard;

enum UserRole { user, eventPlanner, admin }

UserRole userRoleFromString(String value) {
  return switch (value) {
    'event_planner' => UserRole.eventPlanner,
    'admin' => UserRole.admin,
    _ => UserRole.user,
  };
}

/// Mirrors a row in `public.users`. Shared across every feature that needs
/// to render or check a profile — organizer info on an event, a reviewer's
/// name, premium-gating, a host's or guest's identity.
///
/// `username` is the unique public handle (see
/// 0008_username_and_remove_phone.sql) — nullable because it's chosen
/// post-signup, not at auth time. There's no `phone` anymore: phone-based
/// auth was removed, email (password or Google) is the only sign-in method.
class AppUserProfile extends Equatable {
  const AppUserProfile({
    required this.id,
    this.username,
    this.email,
    this.name,
    this.city,
    this.photoUrl,
    this.bio,
    required this.isVerified,
    required this.tier,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String? username;
  final String? email;
  final String? name;
  final String? city;
  final String? photoUrl;
  final String? bio;
  final bool isVerified;
  final UserTier tier;
  final UserRole role;
  final DateTime createdAt;

  bool get isPremium => tier == UserTier.premium;
  bool get hasCompletedProfile =>
      (name ?? '').trim().isNotEmpty && (city ?? '').trim().isNotEmpty && (username ?? '').trim().isNotEmpty;

  /// Only event planners and admins can organize events — see
  /// `events_insert_own` in 0005_roles_and_email_auth.sql.
  bool get canOrganizeEvents => role == UserRole.eventPlanner || role == UserRole.admin;

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      id: json['id'] as String,
      username: json['username'] as String?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      city: json['city'] as String?,
      photoUrl: json['photo_url'] as String?,
      bio: json['bio'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      tier: userTierFromString(json['tier'] as String? ?? 'standard'),
      role: userRoleFromString(json['role'] as String? ?? 'user'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, username, email, name, city, photoUrl, bio, isVerified, tier, role, createdAt];
}
