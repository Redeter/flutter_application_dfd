import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/foundation_sphere.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';

/// Галочки «сфера важна» — в расчёте целей или нет.
class FoundationSphereCheckboxes extends StatelessWidget {
  const FoundationSphereCheckboxes({
    super.key,
    required this.priorities,
    required this.onChanged,
    this.dense = false,
  });

  final FoundationSpherePriorities priorities;
  final void Function(FoundationSpherePriorities next) onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!dense)
          Text(
            'Какие сферы учитывать в целях',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (!dense) const SizedBox(height: 4),
        if (!dense)
          Text(
            'Снятая галочка — сфера скрыта и не влияет на фундамент.',
            style: GoogleFonts.alegreyaSans(
              fontSize: 12,
              height: 1.3,
              color: AppColors.textDark.withValues(alpha: 0.65),
            ),
          ),
        if (!dense) const SizedBox(height: 6),
        ...FoundationSphereIds.ordered.map((id) {
          final active = priorities.isActive(id);
          return CheckboxListTile(
            value: active,
            onChanged: (v) {
              onChanged(priorities.copyWithId(id, v == true));
            },
            contentPadding: dense ? EdgeInsets.zero : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppCheckboxStyle.activeColor,
            checkColor: AppCheckboxStyle.checkColor,
            side: AppCheckboxStyle.side,
            title: Text(
              id.foundationLabel,
              style: AppTypography.checkboxTileTitle(dense: dense),
            ),
            subtitle: id == FoundationSphereIds.medication && active
                ? Text(
                    'Цель по приёмам задаётся в календаре',
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 11,
                      color: AppColors.textDark.withValues(alpha: 0.6),
                    ),
                  )
                : null,
          );
        }),
      ],
    );
  }
}
