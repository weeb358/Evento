import 'package:equatable/equatable.dart';

/// City/category/date are free for everyone. Price range, distance radius,
/// and the "next N hours" time window are Premium-only — the events list
/// screen only lets a non-premium user set them via [PremiumGate], but the
/// filter object itself doesn't care who's applying it.
class EventFilters extends Equatable {
  const EventFilters({
    this.city,
    this.category,
    this.dateFrom,
    this.dateTo,
    this.searchQuery,
    this.maxPrice,
    this.radiusKm,
    this.originLat,
    this.originLng,
    this.withinNextHours,
  });

  final String? city;
  final String? category;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? searchQuery;
  final double? maxPrice;
  final double? radiusKm;
  final double? originLat;
  final double? originLng;
  final int? withinNextHours;

  bool get hasAdvancedFilters => maxPrice != null || radiusKm != null || withinNextHours != null;

  EventFilters copyWith({
    String? city,
    bool clearCity = false,
    String? category,
    bool clearCategory = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDates = false,
    String? searchQuery,
    double? maxPrice,
    bool clearMaxPrice = false,
    double? radiusKm,
    bool clearRadius = false,
    double? originLat,
    double? originLng,
    int? withinNextHours,
    bool clearWithinNextHours = false,
  }) {
    return EventFilters(
      city: clearCity ? null : (city ?? this.city),
      category: clearCategory ? null : (category ?? this.category),
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      searchQuery: searchQuery ?? this.searchQuery,
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      radiusKm: clearRadius ? null : (radiusKm ?? this.radiusKm),
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      withinNextHours: clearWithinNextHours ? null : (withinNextHours ?? this.withinNextHours),
    );
  }

  @override
  List<Object?> get props => [
    city,
    category,
    dateFrom,
    dateTo,
    searchQuery,
    maxPrice,
    radiusKm,
    originLat,
    originLng,
    withinNextHours,
  ];
}
