import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Текстовые стили. Для полей ввода — [formField], без small caps (SC).
abstract final class AppTypography {
  static TextStyle get formField => GoogleFonts.alegreyaSans(
        fontSize: 16,
        height: 1.35,
        color: AppColors.textDark,
      );

  /// Заголовок над полем ввода (профиль, формы).
  static TextStyle get fieldLabel => GoogleFonts.alegreyaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  static TextStyle get fieldHelper => GoogleFonts.alegreyaSans(
        fontSize: 12,
        height: 1.35,
        color: AppColors.textDark.withValues(alpha: 0.62),
      );

  /// Подпись у чекбокса (диагнозы, сферы в целях).
  static TextStyle checkboxTileTitle({bool dense = false}) =>
      GoogleFonts.alegreyaSans(
        fontSize: dense ? 14 : 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );
}

/// Общий вид чекбоксов (диагнозы, сферы, профиль).
abstract final class AppCheckboxStyle {
  static const Color activeColor = AppColors.orange;
  static const Color checkColor = AppColors.white;
  static const BorderSide side = BorderSide(color: Colors.black54);
}
