import 'package:equatable/equatable.dart';

enum HomeType { apartment, house, privateRoom, sharedRoom }

HomeType? homeTypeFromString(String? value) {
  return switch (value) {
    'apartment' => HomeType.apartment,
    'house' => HomeType.house,
    'private_room' => HomeType.privateRoom,
    'shared_room' => HomeType.sharedRoom,
    _ => null,
  };
}

String homeTypeToString(HomeType type) {
  return switch (type) {
    HomeType.apartment => 'apartment',
    HomeType.house => 'house',
    HomeType.privateRoom => 'private_room',
    HomeType.sharedRoom => 'shared_room',
  };
}

String homeTypeLabel(HomeType type) {
  return switch (type) {
    HomeType.apartment => 'Apartment',
    HomeType.house => 'House',
    HomeType.privateRoom => 'Private room',
    HomeType.sharedRoom => 'Shared room',
  };
}

enum HostVerificationStatus { unverified, pending, verified }

HostVerificationStatus verificationStatusFromString(String value) {
  return HostVerificationStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => HostVerificationStatus.unverified,
  );
}

/// `id` is the host's user id (1:1 with `public.users`) — see
/// host_profiles in 0002_premium_hosting.sql.
class HostProfile extends Equatable {
  const HostProfile({
    required this.id,
    this.headline,
    this.about,
    this.homeType,
    this.maxGuests,
    this.houseRules,
    required this.isActive,
    required this.verificationStatus,
    this.city,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  final String id;
  final String? headline;
  final String? about;
  final HomeType? homeType;
  final int? maxGuests;
  final String? houseRules;
  final bool isActive;
  final HostVerificationStatus verificationStatus;
  final String? city;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  bool get hasLocation => lat != null && lng != null;
  bool get isVerified => verificationStatus == HostVerificationStatus.verified;

  factory HostProfile.fromJson(Map<String, dynamic> json) {
    return HostProfile(
      id: json['id'] as String,
      headline: json['headline'] as String?,
      about: json['about'] as String?,
      homeType: homeTypeFromString(json['home_type'] as String?),
      maxGuests: json['max_guests'] as int?,
      houseRules: json['house_rules'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      verificationStatus: verificationStatusFromString(json['verification_status'] as String? ?? 'unverified'),
      city: json['city'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    headline,
    about,
    homeType,
    maxGuests,
    houseRules,
    isActive,
    verificationStatus,
    city,
    lat,
    lng,
    createdAt,
  ];
}
