import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'laconic_tap.dart';

Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required String title,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _DeleteConfirmDialog(title: title),
  );
  return result ?? false;
}

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.dialogPrimary, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pillButton('Отмена', onPressed: () => Navigator.pop(context, false)),
                _pillButton('Удалить', onPressed: () => Navigator.pop(context, true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, {required VoidCallback onPressed}) {
    return LaconicTap(
      onTap: onPressed,
      child: Material(
        color: AppColors.dialogPrimary,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
