import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF1A56DB);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  static const Color earlyTeal = Color(0xFF0D9488);
  static const Color overtime = Color(0xFF7C3AED);
  static const Color sidebar = Color(0xFF1E293B);

  static const Color bgPage = Color(0xFFF1F5F9);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textPrimary = Color(0xFF0F172A);

  static const Color sidebarMuted = Color(0xFF94A3B8);
  static const Color sidebarHoverBg = Color(0x0FFFFFFF);
  static const Color sidebarHoverText = Color(0xFFF1F5F9);
  static const Color sidebarDivider = Color(0x1AFFFFFF);
  static const Color sidebarAvatarBg = Color(0xFF334155);
  static const Color sidebarUserCard = Color(0x0DFFFFFF);

  static const Color badgeBgOnTime = Color(0xFFDCFCE7);
  static const Color badgeTextOnTime = Color(0xFF166534);

  static const Color badgeBgLate = Color(0xFFFEF3C7);
  static const Color badgeTextLate = Color(0xFF92400E);

  static const Color badgeBgEarly = Color(0xFFCCFBF1);
  static const Color badgeTextEarly = Color(0xFF134E4A);

  static const Color badgeBgOvertime = Color(0xFFEDE9FE);
  static const Color badgeTextOvertime = Color(0xFF5B21B6);

  static const Color badgeBgOutOfRange = Color(0xFFFEE2E2);
  static const Color badgeTextOutOfRange = Color(0xFF991B1B);

  static const Color badgeBgException = Color(0xFFFEE2E2);
  static const Color badgeTextException = Color(0xFF991B1B);

  static const Color employeeActiveBg = Color(0xFFDCFCE7);
  static const Color employeeActiveText = Color(0xFF166634);
  static const Color employeeInactiveBg = Color(0xFFFEE2E2);
  static const Color employeeInactiveText = Color(0xFF991B1B);

  static const Color exceptionTabAllBg = Color(0xFFEFF6FF);
  static const Color exceptionTabAllText = Color(0xFF1E40AF);
  static const Color exceptionTabAllBorder = Color(0xFFBFDBFE);
  static const Color exceptionTabPendingBorder = Color(0xFFFDE68A);
  static const Color exceptionTabApprovedBorder = Color(0xFFBBF7D0);
  static const Color exceptionTabRejectedBorder = Color(0xFFFECACA);
  static const Color exceptionCardMutedBg = Color(0xFFFAFAFA);

  // DESIGN.md alias tokens (home + mobile UI)
  static const Color primaryLight = Color(0xFFEEF1FF);
  static const Color surface = bgCard;
  static const Color background = bgPage;
  static const Color textSecondary = textMuted;
  static const Color error = danger;
  static const Color successLight = badgeBgOnTime;
  static const Color warningLight = badgeBgLate;
  static const Color overtimeLight = badgeBgOvertime;
  static const Color errorLight = badgeBgException;
  static const Color borderLight = Color(0xFFCBD5E1);
}
