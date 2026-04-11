import 'dart:math' show min;

import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

  bool get isMobile => screenWidth < AppBreakpoints.mobile;
  bool get isTablet =>
      screenWidth >= AppBreakpoints.mobile &&
      screenWidth < AppBreakpoints.tablet;
  bool get isDesktop => screenWidth >= AppBreakpoints.tablet;

  /// Usable content width, capped for readability.
  double get contentWidth {
    if (isMobile) return min(screenWidth, 480);
    if (isTablet) return min(screenWidth, 720);
    return 480; // desktop: fixed 480px centered
  }
}

extension ResponsiveText on BuildContext {
  double get clockSize => isDesktop ? 96 : 80;
  double get kpiSize => isDesktop ? 52 : 44;
  double get h1 => isDesktop ? 20 : 17;
  double get body => 14;
  double get pagePadding => isDesktop ? 32 : 16;
  double get cardGap => isDesktop ? 16 : 12;
}
