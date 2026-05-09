import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Future<TimeOfDay?> showTimePickerModal(BuildContext context, {TimeOfDay? initial}) async {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (ctx) => _TimePickerModal(initial: initial ?? const TimeOfDay(hour: 8, minute: 0)),
  );
}

class _TimePickerModal extends StatefulWidget {
  const _TimePickerModal({required this.initial});

  final TimeOfDay initial;

  @override
  State<_TimePickerModal> createState() => _TimePickerModalState();
}

class _TimePickerModalState extends State<_TimePickerModal> {
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _time = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.dialogPrimary, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ВЫБЕРИТЕ ТОЧНОЕ ВРЕМЯ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 168,
              child: CupertinoTheme(
                data: CupertinoTheme.of(context).copyWith(
                  brightness: Brightness.light,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    _time.hour,
                    _time.minute,
                  ),
                  use24hFormat: true,
                  onDateTimeChanged: (dt) {
                    setState(() => _time = TimeOfDay(hour: dt.hour, minute: dt.minute));
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _pillButton('Отмена', onPressed: () => Navigator.pop(context, null)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pillButton('Установить', onPressed: () => Navigator.pop(context, _time)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, {required VoidCallback onPressed}) {
    return Material(
      color: AppColors.dialogPrimary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
