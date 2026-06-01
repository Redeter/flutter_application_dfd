import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

typedef PinDigitCallback = void Function(String digit);
typedef PinBackspaceCallback = void Function();

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final PinDigitCallback onDigit;
  final PinBackspaceCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const keys = <String>[
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '', '0', '⌫',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final label = keys[index];
        if (label.isEmpty) return const SizedBox.shrink();

        final isBackspace = label == '⌫';
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: !enabled
                ? null
                : () {
                    if (isBackspace) {
                      onBackspace();
                    } else {
                      onDigit(label);
                    }
                  },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.white
                    : AppColors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.greyMuted),
              ),
              child: Center(
                child: isBackspace
                    ? Icon(
                        Icons.backspace_outlined,
                        color: enabled ? AppColors.textDark : AppColors.greyMuted,
                      )
                    : Text(
                        label,
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: enabled ? AppColors.textDark : AppColors.greyMuted,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PinDotsIndicator extends StatelessWidget {
  const PinDotsIndicator({
    super.key,
    required this.length,
    required this.filled,
    this.shake = false,
  });

  final int length;
  final int filled;
  final bool shake;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: Matrix4.translationValues(shake ? 8 : 0, 0, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(length, (index) {
          final isFilled = index < filled;
          return Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? AppColors.orange : Colors.transparent,
              border: Border.all(
                color: isFilled ? AppColors.orange : AppColors.textDark.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }
}
