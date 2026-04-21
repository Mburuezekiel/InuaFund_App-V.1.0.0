import 'package:flutter/material.dart';

class AppColors {
  // Primary brand — Green 500 / 600
  static const primary        = Color(0xFF4CAF50); // Green 500
  static const primaryLight   = Color(0xFF81C784); // Green 300 (lighter)
  static const primaryDark    = Color(0xFF388E3C); // Green 600

  // Accent — keep warm amber for contrast
  static const accent         = Color(0xFFFFA000); // Amber 700
  static const accentDark     = Color(0xFFFF8F00); // Amber 800

  // Semantic
  static const success        = Color(0xFF2E7D32); // Dark green
  static const warning        = Color(0xFFF57C00); // Orange
  static const error          = Color(0xFFD32F2F); // Red
  static const info           = Color(0xFF1976D2); // Blue

  // Neutrals
  static const background     = Color(0xFFF8FAF9);
  static const surface        = Color(0xFFFFFFFF);
  static const textPrimary    = Color(0xFF1A1A1A);
  static const textSecondary  = Color(0xFF6B7280);
  static const textHint       = Color(0xFFB4B2A9);
  static const border         = Color(0xFFE5E7EB);

  // Notifications
  static const notifDonation  = primary;
  static const notifMilestone = accent;
  static const notifUpdate    = info;
}