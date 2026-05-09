import 'package:flutter/material.dart';

/// Цвета из макета заметок и общая палитра приложения.
abstract final class AppColors {
  static const Color orange = Color(0xFFFFAB6D);
  /// Основные кнопки во всплывающих окнах (диалоги, модальные листы).
  static const Color dialogPrimary = Color(0xFFF6A96F);
  static const Color peachBackground = Color(0xFFFFD8B1);
  static const Color cream = Color(0xFFFFF6EF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color greyPlaceholder = Color(0xFFD0D0D0);
  static const Color greyMuted = Color(0xFFD8D1CC);
  static const Color textDark = Color(0xFF4A4A4A);

  // Цвета для экранов состояния
  static const Color orangeHandle = Color(0xFFF2994A);
  static const Color lavender = Color(0xFFE2DDF0);
  static const Color lightPink = Color(0xFFFFE4E4);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color lightYellow = Color(0xFFFFF9E6);
  static const Color purple = Color(0xFF9B51E0);

  // Календарь
  static const Color appointmentCardFrame = Color(0xFFEEC09D);
  static const Color headerPeach = Color(0xFFFBC490);
  static const Color creamBg = Color(0xFFFDF1E6);
  static const Color skipRed = Color(0xFFFFCDD2);
  static const Color takeGreen = Color(0xFFC8E6C9);
  static const Color takeYellow = Color(0xFFFFF9C4);
}
