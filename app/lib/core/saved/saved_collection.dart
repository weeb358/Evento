import 'package:equatable/equatable.dart';

class SavedCollection extends Equatable {
  const SavedCollection({
    required this.id,
    required this.userId,
    required this.name,
    required this.isDefault,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final bool isDefault;
  final DateTime createdAt;

  factory SavedCollection.fromJson(Map<String, dynamic> json) {
    return SavedCollection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, userId, name, isDefault, createdAt];
}
