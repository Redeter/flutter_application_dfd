import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Фон как в макете: кремовая база (scaffold), крупные персиковые круги, лёгкий акцент снизу.
class CreamBackgroundDecor extends StatelessWidget {
  const CreamBackgroundDecor({super.key});

  static const Color _peachBlob = Color(0xFFF8C994);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -160,
            left: -110,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _peachBlob.withValues(alpha: 0.42),
              ),
            ),
          ),
          Positioned(
            top: -72,
            right: -76,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 8,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.45),
                  width: 3,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 72,
            left: -68,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _peachBlob.withValues(alpha: 0.32),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 4,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
