import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

// --- Единая геометрия персиковой шапки и полосы дат ---

/// Высота строки с круглыми кнопками / заголовком (диаметр + вертикальные поля).
const double kPeachAppBarToolbarHeight = 52;

/// Диаметр круглых leading/actions на персиковой шапке.
const double kPeachAppBarActionDiameter = 46;

/// Размер глифа внутри круга.
const double kPeachAppBarActionIconSize = 22;

/// Заголовок шапки (Статистика, Заметки, дата в календаре).
const double kPeachAppBarTitleFontSize = 22;

/// Горизонтальный отступ ряда иконок+текста (календарь без [AppBar]).
const double kPeachAppBarHorizontalInset = 16;

/// Слот [AppBar.leading] под круг «назад».
const double kPeachAppBarLeadingWidth = 56;

/// Отступы группы [AppBar.actions] от краёв.
const EdgeInsetsDirectional kPeachAppBarActionsPadding =
    EdgeInsetsDirectional.only(start: 4, end: 10);

/// Зазор под [AppBar] до полосы дат и низ полосы в персиковом блоке.
const double kPeachHeaderStripTopGap = 6;
const double kPeachHeaderStripBottomPadding = 14;

/// Диск кнопки: ярче персиковой шапки — сильнее тянем к [AppColors.orange], чтобы читалось контрастнее.
Color peachAppBarCircleFill() =>
    Color.lerp(AppColors.headerPeach, AppColors.orange, 0.72)!;

/// Круглая кнопка на персиковой шапке: более сочный диск + белая иконка + лёгкая тень.
ButtonStyle peachAppBarCircleIconButtonStyle({
  double diameter = kPeachAppBarActionDiameter,
  double iconSize = kPeachAppBarActionIconSize,
}) {
  return IconButton.styleFrom(
    backgroundColor: peachAppBarCircleFill(),
    foregroundColor: AppColors.white,
    overlayColor: AppColors.white.withValues(alpha: 0.22),
    shadowColor: AppColors.orange.withValues(alpha: 0.45),
    elevation: 2,
    surfaceTintColor: Colors.transparent,
    shape: const CircleBorder(),
    padding: EdgeInsets.zero,
    minimumSize: Size(diameter, diameter),
    fixedSize: Size(diameter, diameter),
    iconSize: iconSize,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

/// Заголовок на персиковой шапке: белый текст с лёгкой тенью для читаемости.
TextStyle peachAppBarTitleStyle() => GoogleFonts.alegreyaSans(
      fontSize: kPeachAppBarTitleFontSize,
      fontWeight: FontWeight.w800,
      color: AppColors.white,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.26),
          offset: const Offset(0, 1),
          blurRadius: 3,
        ),
      ],
    );
