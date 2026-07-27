import 'package:flutter/material.dart';

/// Brand color tokens. Source of truth: docs/DESIGN_SYSTEM.md — keep in sync.
abstract final class AppColors {
  static const brandLight = Color(0xFFFF5A3C);
  static const brandStrongLight = Color(0xFFE4472B);
  static const bgBaseLight = Color(0xFFFFFFFF);
  static const bgSurfaceLight = Color(0xFFF7F6F4);
  static const bgSurfaceRaisedLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF171412);
  static const textSecondaryLight = Color(0xFF6B6560);
  static const borderLight = Color(0xFFE8E5E1);

  static const brandDark = Color(0xFFFF6B4A);
  static const brandStrongDark = Color(0xFFFF8563);
  static const bgBaseDark = Color(0xFF121212);
  static const bgSurfaceDark = Color(0xFF1B1B1B);
  static const bgSurfaceRaisedDark = Color(0xFF222222);
  static const textPrimaryDark = Color(0xFFF5F3F1);
  static const textSecondaryDark = Color(0xFFA8A29C);
  static const borderDark = Color(0xFF2E2E2E);

  static const success = Color(0xFF1E9E5A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
}
