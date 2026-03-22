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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.orange, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ВЫБЕРИТЕ ТОЧНОЕ ВРЕМЯ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pillButton('Отмена', onPressed: () => Navigator.pop(context, null)),
                _pillButton('Установить', onPressed: () => Navigator.pop(context, _time)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, {required VoidCallback onPressed}) {
    return Material(
      color: AppColors.orange,
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
    );
  }
}
