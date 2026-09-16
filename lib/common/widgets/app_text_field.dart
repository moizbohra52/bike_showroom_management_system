import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The application's text input.
///
/// Wraps `TextFormField` to standardise the label, the required marker, the
/// helper and error presentation, and the keyboard configuration — and to
/// provide the specialised constructors the domain needs, where the wrong
/// keyboard or the wrong input formatter is a real source of bad data.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.prefixIcon,
    this.suffix,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.isRequired = false,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.autofillHints,
    this.focusNode,
    this.onTap,
    super.key,
  });

  /// Email address: no capitalisation, email keyboard, autofill wired up.
  const AppTextField.email({
    this.label = 'Email address',
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.isRequired = true,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    super.key,
  }) : keyboardType = TextInputType.emailAddress,
       textCapitalization = TextCapitalization.none,
       inputFormatters = null,
       prefixIcon = Icons.mail_outline,
       suffix = null,
       maxLength = 254,
       maxLines = 1,
       minLines = null,
       obscureText = false,
       autofillHints = const <String>[AutofillHints.email],
       onTap = null;

  /// Indian mobile number: digits only, capped at ten.
  ///
  /// The formatter matters as much as the keyboard — a numeric keyboard still
  /// permits pasted text, and a phone column with spaces in it defeats the
  /// unique index on `(showroom_id, phone)`.
  AppTextField.phone({
    this.label = 'Mobile number',
    this.controller,
    this.initialValue,
    this.hint = '10-digit mobile number',
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.isRequired = true,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    super.key,
  }) : keyboardType = TextInputType.phone,
       textCapitalization = TextCapitalization.none,
       inputFormatters = <TextInputFormatter>[
         FilteringTextInputFormatter.digitsOnly,
         LengthLimitingTextInputFormatter(10),
       ],
       prefixIcon = Icons.phone_outlined,
       suffix = null,
       maxLength = 10,
       maxLines = 1,
       minLines = null,
       obscureText = false,
       autofillHints = const <String>[AutofillHints.telephoneNumber],
       onTap = null;

  /// Monetary amount: decimal keyboard, at most two decimal places.
  AppTextField.money({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.isRequired = true,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    super.key,
  }) : keyboardType = const TextInputType.numberWithOptions(decimal: true),
       textCapitalization = TextCapitalization.none,
       inputFormatters = <TextInputFormatter>[
         // Permits an in-progress entry such as "12." while rejecting a third
         // decimal place, which would be silently rounded on save.
         FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
       ],
       prefixIcon = null,
       suffix = const Text(AppConstants.defaultCurrencySymbol),
       maxLength = null,
       maxLines = 1,
       minLines = null,
       obscureText = false,
       autofillHints = null,
       onTap = null;

  /// Whole number, for quantity and odometer.
  AppTextField.integer({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.isRequired = true,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.maxLength,
    super.key,
  }) : keyboardType = TextInputType.number,
       textCapitalization = TextCapitalization.none,
       inputFormatters = <TextInputFormatter>[
         FilteringTextInputFormatter.digitsOnly,
       ],
       prefixIcon = null,
       maxLines = 1,
       minLines = null,
       obscureText = false,
       autofillHints = null,
       onTap = null;

  /// Uppercase identifier: chassis and engine numbers, registration marks,
  /// GST and PAN. Forces uppercase as the user types, because these are stored
  /// uppercase and a mixed-case entry would not match a lookup.
  AppTextField.code({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.maxLength,
    this.isRequired = true,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    super.key,
  }) : keyboardType = TextInputType.text,
       textCapitalization = TextCapitalization.characters,
       inputFormatters = <TextInputFormatter>[UpperCaseTextFormatter()],
       suffix = null,
       maxLines = 1,
       minLines = null,
       obscureText = false,
       autofillHints = null,
       onTap = null;

  /// Free-form multi-line text: notes, complaints, work done.
  const AppTextField.multiline({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.maxLength,
    this.maxLines = 5,
    this.minLines = 3,
    this.isRequired = false,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.autofocus = false,
    this.focusNode,
    super.key,
  }) : keyboardType = TextInputType.multiline,
       textCapitalization = TextCapitalization.sentences,
       inputFormatters = null,
       prefixIcon = null,
       suffix = null,
       obscureText = false,
       autofillHints = null,
       textInputAction = TextInputAction.newline,
       onSubmitted = null,
       onTap = null;

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;

  /// Server-supplied error, projected from a `ValidationException`'s
  /// `fieldErrors`. Shown alongside local validation.
  final String? errorText;

  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool isRequired;
  final bool isEnabled;
  final bool isReadOnly;
  final bool obscureText;
  final bool autofocus;
  final List<String>? autofillHints;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // A separate label above the field rather than a floating one: in a
        // dense form the label must stay readable while the field holds a
        // value, and a fixed label keeps row heights uniform.
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
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          enabled: isEnabled,
          readOnly: isReadOnly,
          obscureText: obscureText,
          autofocus: autofocus,
          autofillHints: autofillHints,
          focusNode: focusNode,
          onTap: onTap,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            errorText: errorText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
            // Padding only — deliberately NOT wrapped in an `Align`.
            //
            // `suffixIconConstraints` leaves the width unbounded, so the
            // maximum InputDecorator enforces is the whole field. An `Align`
            // given a finite maximum expands to fill it, which handed the
            // suffix the entire width and left the editable area at zero.
            // The icon still painted at the right edge, so the field looked
            // perfectly normal while being impossible to click or type in —
            // which made signing in impossible, since the password field is
            // the only one with a suffix. `Padding` shrink-wraps its child,
            // and the suffix is already placed at the trailing edge by the
            // decoration itself, so nothing needs aligning.
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: suffix,
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            // The counter is noise on most fields; a max length is a guard,
            // not a target the user should be watching.
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Forces input to uppercase while preserving the cursor position.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => TextEditingValue(
    text: newValue.text.toUpperCase(),
    selection: newValue.selection,
    composing: TextRange.empty,
  );
}

/// A password field with a reveal toggle.
///
/// Stateful because the visibility toggle is local UI state with no business
/// meaning; putting it in a controller would be noise.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    this.label = 'Password',
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.isRequired = true,
    this.isEnabled = true,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const <String>[AutofillHints.password],
    this.focusNode,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool isRequired;
  final bool isEnabled;
  final bool autofocus;
  final TextInputAction textInputAction;
  final List<String>? autofillHints;
  final FocusNode? focusNode;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool obscured = true;

  @override
  Widget build(BuildContext context) => AppTextField(
    label: widget.label,
    controller: widget.controller,
    hint: widget.hint,
    helper: widget.helper,
    errorText: widget.errorText,
    validator: widget.validator,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    isRequired: widget.isRequired,
    isEnabled: widget.isEnabled,
    autofocus: widget.autofocus,
    obscureText: obscured,
    keyboardType: TextInputType.visiblePassword,
    textInputAction: widget.textInputAction,
    autofillHints: widget.autofillHints,
    focusNode: widget.focusNode,
    prefixIcon: Icons.lock_outline,
    suffix: IconButton(
      onPressed: () => setState(() => obscured = !obscured),
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      tooltip: obscured ? 'Show password' : 'Hide password',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    ),
  );
}
