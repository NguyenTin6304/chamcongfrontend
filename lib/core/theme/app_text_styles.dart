import 'package:flutter/material.dart';

/// Named text style catalogue for Birdle.
///
/// Rules:
/// - Styles define structure (size, weight, tracking) but NOT color.
///   Apply color at the call site via `.copyWith(color: AppColors.xxx)`.
/// - Two styles are responsive (clockDisplay, kpiNumber): their fontSize
///   depends on screen width. Apply size via the responsive context extension:
///   `AppTextStyles.clockDisplay.copyWith(fontSize: context.clockSize)`.
/// - All styles are `const` — zero runtime allocation.
abstract final class AppTextStyles {
  // ── Responsive display ────────────────────────────────────────────────────
  // Apply fontSize via: .copyWith(fontSize: context.clockSize)  [80 / 96]

  /// Full-screen clock on the home page.
  static const TextStyle clockDisplay = TextStyle(
    fontWeight: FontWeight.w700,
    height: 1.0,
  );

  /// KPI numbers on the history / summary screens.
  // Apply fontSize via: .copyWith(fontSize: context.kpiSize)  [44 / 52]
  static const TextStyle kpiNumber = TextStyle(
    fontWeight: FontWeight.w700,
  );

  // ── App chrome ────────────────────────────────────────────────────────────

  /// AppBar title, page header brand text.
  static const TextStyle headerTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  // ── Content hierarchy ─────────────────────────────────────────────────────

  /// Primary section headings: "Tổng hợp hôm nay", "Sự kiện gần nhất".
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// CTA and dialog button labels.
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Card titles, activity item primary label.
  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Standard readable body text.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Chip labels, AM/PM suffix, time display in lists.
  static const TextStyle chipText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Secondary info in activity items, snack bar text.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  /// Captions, timestamps, form helper text.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Bold captions used for section sub-labels and list date headers.
  static const TextStyle captionBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ── Micro-labels ──────────────────────────────────────────────────────────

  /// Uppercase section labels: "SỰ KIỆN GẦN NHẤT", "GIẢI TRÌNH ĐÃ GỬI".
  /// Typically rendered in ALL CAPS via TextCapitalization or direct string.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Status badges and outcome labels: "THÀNH CÔNG", "ĐÚNG GIỜ".
  static const TextStyle badgeLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  // ── Specialised ───────────────────────────────────────────────────────────

  /// Map overlay: lat/lng, accuracy — monospaced digits.
  static const TextStyle mapOverlay = TextStyle(
    fontSize: 10,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
