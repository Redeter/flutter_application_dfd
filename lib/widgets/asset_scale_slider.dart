import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Шкала из SVG сверху, маркер «Slider pick.svg» на дорожке под шкалой (1–10).
class AssetScaleSlider extends StatelessWidget {
  const AssetScaleSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.scaleAssetPath,
    this.thumbSize = 44,
    this.spacingBelowScale = 12,
    this.thumbTrackPadding = 4,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String scaleAssetPath;

  /// Общий ассет маркера ползунка.
  static const String thumbAssetPath = 'assets/icons/Slider pick.svg';

  final double thumbSize;

  /// Зазор между нижним краем шкалы и дорожкой ползунка.
  final double spacingBelowScale;

  /// Вертикальные отступы внутри полоски под шкалой.
  final double thumbTrackPadding;

  int get _iv => value.round().clamp(1, 10);

  double _thumbCenterX(double width) {
    final pad = thumbSize / 2;
    final usable = math.max(width - thumbSize, 1.0);
    return pad + usable * ((_iv - 1) / 9);
  }

  void _applyDx(double dx, double width) {
    final pad = thumbSize / 2;
    final usable = math.max(width - thumbSize, 1.0);
    final clamped = (dx - pad).clamp(0.0, usable);
    final raw = 1 + (clamped / usable) * 9;
    final snapped = raw.round().clamp(1, 10).toDouble();
    if (snapped != value) {
      onChanged(snapped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cx = _thumbCenterX(w);
        final trackHeight = thumbSize + thumbTrackPadding * 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _applyDx(d.localPosition.dx, w),
          onHorizontalDragUpdate: (d) => _applyDx(d.localPosition.dx, w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(scaleAssetPath, fit: BoxFit.fitWidth),
              SizedBox(height: spacingBelowScale),
              SizedBox(
                height: trackHeight,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: cx - thumbSize / 2,
                      top: thumbTrackPadding,
                      child: SvgPicture.asset(
                        thumbAssetPath,
                        width: thumbSize,
                        height: thumbSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
