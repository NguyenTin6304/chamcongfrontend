import 'package:flutter/material.dart';

/// 4-px-grid spacing scale.
///
/// Use these instead of raw numeric literals for padding / gap / margin.
/// All values are multiples of 4. Off-grid values (5, 7, 9, 10, 14…) that
/// appear in older code should be migrated to the nearest grid stop.
abstract final class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;

  // Common EdgeInsets shortcuts
  static const EdgeInsets paddingAllSm  = EdgeInsets.all(sm);
  static const EdgeInsets paddingAllMd  = EdgeInsets.all(md);
  static const EdgeInsets paddingAllLg  = EdgeInsets.all(lg);

  static const EdgeInsets paddingHLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHMd = EdgeInsets.symmetric(horizontal: md);

  static const EdgeInsets cardPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: lg);
}

/// Fixed sizing constants — buttons, avatars, icons, containers, touch targets.
abstract final class AppSizes {
  // ── Buttons ───────────────────────────────────────────────────────────────
  static const double buttonHeight = 56;

  // ── Avatar & icons ────────────────────────────────────────────────────────
  /// Profile page avatar diameter.
  static const double avatarSize = 80;

  /// Header circular avatar radius (CircleAvatar).
  static const double headerAvatarRadius = 18;

  /// Icon box inside activity / exception cards (40×40).
  static const double iconBoxSize = 40;

  /// Smaller icon box used in exception type chip (36×36).
  static const double iconBoxSizeSm = 36;

  /// GPS marker dot on the map.
  static const double markerSize = 15;

  // ── Touch targets ─────────────────────────────────────────────────────────
  /// Material Design minimum interactive target: 48×48 dp.
  static const double touchTargetMin = 48;

  /// GPS locate / refresh button on the map.
  static const double locateButtonSize = 48;

  // ── Map ───────────────────────────────────────────────────────────────────
  static const double mapHeightMobile  = 200;
  static const double mapHeightDesktop = 260;

  // ── Layout caps ──────────────────────────────────────────────────────────
  /// Max width of the login / register form column.
  static const double loginFormMaxWidth = 440;

  /// Max width of the CTA button on desktop.
  static const double desktopCtaMaxWidth = 480;

  /// Left panel width in the split-panel exception / admin layout (desktop).
  static const double panelListWidthDesktop = 380;

  /// Left panel width in the split-panel exception / admin layout (tablet).
  static const double panelListWidthTablet = 300;
}

/// Border-radius catalogue.
///
/// Prefer the pre-built [BorderRadius] constants to avoid
/// `BorderRadius.circular(x)` calls scattered everywhere.
abstract final class AppRadius {
  // ── Raw doubles (use when you need Radius.circular or individual corners) ─
  static const double card    = 12;
  static const double button  = 28;  // pill CTA
  static const double chip    = 20;  // GPS chip, punctuality chip
  static const double iconBox = 10;  // icon boxes inside cards
  static const double small   =  6;  // map overlays, small panels
  static const double badge   = 999; // full-pill status badges

  // ── Pre-built BorderRadius ────────────────────────────────────────────────
  static const BorderRadius cardAll    = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonAll  = BorderRadius.all(Radius.circular(button));
  static const BorderRadius chipAll    = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius iconBoxAll = BorderRadius.all(Radius.circular(iconBox));
  static const BorderRadius smallAll   = BorderRadius.all(Radius.circular(small));
  static const BorderRadius badgeAll   = BorderRadius.all(Radius.circular(badge));
}

/// Box-shadow presets.
///
/// Use [AppShadows.card] as the default for surface cards.
/// Escalate to [elevated] or [primaryGlow] for interactive / selected states.
abstract final class AppShadows {
  /// Default card shadow — activity items, summary cards, exception cards.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000), // black @ 4 %
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Stronger shadow for elevated surfaces — selected card, dialogs.
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x14000000), // black @ 8 %
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Map UI elements — locate button, coordinate overlay.
  static const List<BoxShadow> mapElement = [
    BoxShadow(
      color: Color(0x1F000000), // black @ 12 %
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Primary-tinted glow for selected / active cards.
  /// Color is AppColors.primary (#1A56DB) at 15 % opacity.
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x261A56DB),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}
