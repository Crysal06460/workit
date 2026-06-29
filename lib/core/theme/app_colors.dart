import 'package:flutter/material.dart';

/// WorkIt Design System — Couleurs
/// Basé sur la maquette interactive (juin 2026)
abstract class AppColors {
  // ── Primaire ──────────────────────────────────────────
  static const Color primary      = Color(0xFF2563EB);
  static const Color primaryDark  = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);

  // ── Succès / Vert ─────────────────────────────────────
  static const Color success      = Color(0xFF059669);
  static const Color successLight = Color(0xFFECFDF5);

  // ── Avertissement / Orange ────────────────────────────
  static const Color warning      = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);

  // ── Danger / Rouge ────────────────────────────────────
  static const Color danger       = Color(0xFFDC2626);
  static const Color dangerLight  = Color(0xFFFEF2F2);

  // ── Violet ────────────────────────────────────────────
  static const Color purple      = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFFF5F3FF);

  // ── Ambre ─────────────────────────────────────────────
  static const Color amber      = Color(0xFF92400E);
  static const Color amberLight = Color(0xFFFEF3C7);

  // ── Neutres ───────────────────────────────────────────
  static const Color grey50  = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // ── Surfaces ──────────────────────────────────────────
  static const Color background   = Color(0xFFF9FAFB);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color cardBorder   = Color(0xFFF3F4F6);

  // ── Roles ─────────────────────────────────────────────
  static const Color roleCommercial = primary;
  static const Color roleMetteur    = purple;
  static const Color rolePoseur     = success;

  // ── Statuts (badge bg / badge text) ───────────────────
  static const Color statusAttenteBg  = warningLight;
  static const Color statusAttenteText = warning;

  static const Color statusProgBg   = purpleLight;
  static const Color statusProgText = purple;

  static const Color statusOrderBg   = amberLight;
  static const Color statusOrderText = amber;

  static const Color statusPlanBg   = primaryLight;
  static const Color statusPlanText = primaryDark;

  static const Color statusPoseBg   = successLight;
  static const Color statusPoseText = success;

  static const Color statusDoneBg   = grey100;
  static const Color statusDoneText = grey500;

  static const Color statusCloseBg   = Color(0xFFFEE2E2);
  static const Color statusCloseText = Color(0xFF991B1B);

  static const Color statusProblemBg   = dangerLight;
  static const Color statusProblemText = danger;
}
