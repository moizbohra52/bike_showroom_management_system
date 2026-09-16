import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:flutter/material.dart';

/// A text-field-shaped date picker.
///
/// Opens the platform date picker rather than accepting typed text, which
/// rules out an unparseable date entirely — the field always holds either a
/// valid date or nothing.
class AppDatePicker extends StatelessWidget {
  const AppDatePicker({
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.isRequired = false,
    this.isEnabled = true,
    this.errorText,
    this.hint = 'Select date',
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool isRequired;
  final bool isEnabled;
  final String? errorText;
  final String hint;

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(now.year - 20),
      lastDate: lastDate ?? DateTime(now.year + 20),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: RichText(
            text: TextSpan(
              text: label,
              style: AppTypography.labelMedium.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              children: <InlineSpan>[
                if (isRequired)
                  TextSpan(
                    text: ' *',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: isEnabled ? () => _pick(context) : null,
          borderRadius: AppRadius.mdAll,
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: errorText,
              suffixIcon: value == null
                  ? const Icon(Icons.calendar_today_outlined, size: 16)
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: isEnabled ? () => onChanged(null) : null,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Clear',
                    ),
            ),
            child: Text(
              value == null ? hint : DateUtil.format(value),
              style: AppTypography.bodyMedium.copyWith(
                color: value == null
                    ? theme.textTheme.bodySmall?.color
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks a [DateRange] via two sequential date pickers, or a named preset.
class AppDateRangeField extends StatelessWidget {
  const AppDateRangeField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final DateRange? value;
  final ValueChanged<DateRange?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: value == null
          ? null
          : DateTimeRange(start: value!.start, end: value!.end),
    );
    if (picked != null) {
      onChanged(DateRange(start: picked.start, end: picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(label, style: AppTypography.labelMedium),
        ),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: AppRadius.mdAll,
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: value == null
                  ? const Icon(Icons.date_range_outlined, size: 16)
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => onChanged(null),
                      visualDensity: VisualDensity.compact,
                    ),
            ),
            child: Text(
              value == null ? 'Any date' : value!.label,
              style: AppTypography.bodyMedium.copyWith(
                color: value == null
                    ? theme.textTheme.bodySmall?.color
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
