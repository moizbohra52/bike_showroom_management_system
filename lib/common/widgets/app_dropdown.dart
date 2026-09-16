import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:flutter/material.dart';

/// A labelled dropdown, matching [AppTextField]'s label/required presentation
/// so a form mixing text fields and dropdowns looks like one system.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.value,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.isRequired = false,
    this.isEnabled = true,
    this.validator,
    super.key,
  });

  final String label;
  final List<T> items;
  final String Function(T item) itemLabel;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final String? errorText;
  final bool isRequired;
  final bool isEnabled;
  final String? Function(T?)? validator;

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
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          items: items
              .map(
                (T item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: isEnabled ? onChanged : null,
          validator: validator,
          decoration: InputDecoration(hintText: hint, errorText: errorText),
        ),
      ],
    );
  }
}
