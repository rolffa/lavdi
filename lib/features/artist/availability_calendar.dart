import 'package:flutter/material.dart';

import '../../core/calendar_logic.dart';
import '../../core/format.dart';
import '../../core/theme.dart';

class AvailabilityCalendar extends StatelessWidget {
  const AvailabilityCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.availability,
    required this.selected,
    required this.onMonthChanged,
    required this.onDateSelected,
    this.loading = false,
  });

  final DateTime month;
  final DateTime today;
  final Map<DateTime, bool> availability;
  final DateTime? selected;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cells = monthCells(month);
    final canGoBack = canMoveMonth(from: month, delta: -1, today: today);
    final canGoForward = canMoveMonth(from: month, delta: 1, today: today);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
      ),
      child: InkSurface(
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tilgjengelighet', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Grønne datoer er ledige. Klikk en grønn dato for å sende forespørsel.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Forrige måned',
                    onPressed: canGoBack ? () => onMonthChanged(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      formatMonth(month),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Neste måned',
                    onPressed: canGoForward ? () => onMonthChanged(1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final label in calendarWeekdays)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final cell in cells)
                    if (cell == null)
                      const SizedBox.shrink()
                    else
                      _DayCell(
                        day: cell,
                        today: today,
                        available: availability[dateOnly(cell)],
                        selected:
                            selected != null && isSameDay(selected!, cell),
                        onDateSelected: onDateSelected,
                      ),
                ],
              ),
              if (loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 16),
              const Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Legend(color: AppColors.available, label: 'Ledig'),
                  _Legend(color: AppColors.busy, label: 'Opptatt'),
                  _Legend(
                    color: AppColors.paperDeep,
                    label: 'Ikke tilgjengelig',
                  ),
                ],
              ),
            ],
          ),
            );
          },
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color),
          child: const SizedBox(width: 12, height: 12),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.ink),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.available,
    required this.selected,
    required this.onDateSelected,
  });

  final DateTime day;
  final DateTime today;
  final bool? available;
  final bool selected;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final past = isPastDay(day, today);
    final bookable = available == true && !past;
    final booked = available == false;
    final label = bookable
        ? 'Ledig ${day.day}. Send forespørsel'
        : booked
        ? 'Opptatt ${day.day}'
        : past
        ? 'Datoen ${day.day} er passert'
        : 'Ikke tilgjengelig ${day.day}';

    final Color background;
    final Color foreground;
    if (bookable) {
      background = AppColors.available;
      foreground = Colors.white;
    } else if (booked) {
      background = AppColors.busy;
      foreground = Colors.white;
    } else {
      background = AppColors.paperDeep;
      foreground = AppColors.muted;
    }

    final todayMark = isSameDay(day, today);

    return Semantics(
      button: bookable,
      selected: selected,
      label: label,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: selected ? AppColors.ink : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: bookable ? () => onDateSelected(day) : null,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Text(
              '${day.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: todayMark ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
