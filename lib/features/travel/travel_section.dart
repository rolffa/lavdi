import 'package:flutter/material.dart';

import '../../core/format.dart';

class MomentField extends StatelessWidget {
  const MomentField({
    super.key,
    required this.dateLabel,
    required this.timeLabel,
    required this.date,
    required this.time,
    required this.firstDate,
    required this.lastDate,
    required this.fallbackDate,
    required this.onDate,
    required this.onTime,
    this.lockDate = false,
  });

  final String dateLabel;
  final String timeLabel;
  final DateTime? date;
  final TimeOfDay? time;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime fallbackDate;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<TimeOfDay> onTime;
  final bool lockDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PickerButton(
          label: dateLabel,
          value: date == null ? 'Velg dato' : formatLongDate(date!),
          onPressed: lockDate
              ? null
              : () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? fallbackDate,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (picked == null) return;
            onDate(dateOnly(picked));
          },
        ),
        const SizedBox(height: 8),
        _PickerButton(
          label: timeLabel,
          value: time == null ? 'Velg klokkeslett' : formatClock(time!),
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time ?? const TimeOfDay(hour: 14, minute: 0),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
            if (picked == null) return;
            onTime(picked);
          },
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.label, required this.value, required this.onPressed});

  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: $value'),
      ),
    );
  }
}
