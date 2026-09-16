import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Centralised dialog presentation.
///
/// Everything that asks the user to confirm, choose, or fill in a short form
/// goes through here, so sizing, button placement and the busy state behave
/// identically everywhere rather than being reimplemented per screen.
class AppDialog {
  const AppDialog._();

  /// A yes/no confirmation. Returns `true` only on explicit confirmation —
  /// dismissing the dialog (back button, tap outside) resolves to `false`.
  static Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final bool? result = await Get.dialog<bool>(
      _AppDialogShell(
        title: title,
        icon: isDestructive ? Icons.warning_amber_outlined : Icons.help_outline,
        iconColor: isDestructive ? AppColors.danger : AppColors.info,
        content: Text(
          message,
          style: Theme.of(Get.context!).textTheme.bodyMedium,
        ),
        actions: <Widget>[
          AppButton.ghost(
            label: cancelLabel,
            onPressed: () => Get.back(result: false),
          ),
          AppSpacing.hGapSm,
          isDestructive
              ? AppButton.danger(
                  label: confirmLabel,
                  onPressed: () => Get.back(result: true),
                )
              : AppButton.primary(
                  label: confirmLabel,
                  onPressed: () => Get.back(result: true),
                ),
        ],
      ),
      barrierDismissible: true,
    );
    return result ?? false;
  }

  /// Confirmation for a destructive action that requires a typed reason —
  /// used for cancelling a sale, rejecting an expense, reversing a payment.
  /// Returns the trimmed reason, or null if the user backed out.
  static Future<String?> confirmWithReason({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String reasonHint = 'Reason',
    int minLength = 5,
  }) async {
    final TextEditingController controller = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final String? result = await Get.dialog<String>(
      _AppDialogShell(
        title: title,
        icon: Icons.warning_amber_outlined,
        iconColor: AppColors.danger,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(message, style: Theme.of(Get.context!).textTheme.bodyMedium),
              AppSpacing.gapLg,
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(hintText: reasonHint),
                validator: (String? value) {
                  if (value == null || value.trim().length < minLength) {
                    return 'Please enter at least $minLength characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          AppButton.ghost(label: 'Cancel', onPressed: () => Get.back()),
          AppSpacing.hGapSm,
          AppButton.danger(
            label: confirmLabel,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Get.back(result: controller.text.trim());
              }
            },
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  /// A simple informational dialog with a single acknowledgement button.
  static Future<void> info({
    required String title,
    required String message,
    String acknowledgeLabel = 'OK',
  }) => Get.dialog<void>(
    _AppDialogShell(
      title: title,
      icon: Icons.info_outline,
      iconColor: AppColors.info,
      content: Text(
        message,
        style: Theme.of(Get.context!).textTheme.bodyMedium,
      ),
      actions: <Widget>[
        AppButton.primary(label: acknowledgeLabel, onPressed: () => Get.back()),
      ],
    ),
  );

  /// Presents arbitrary [content] in the standard dialog chrome — used for a
  /// compact form (e.g. quick-add customer) that does not warrant a full
  /// screen. The caller is responsible for closing it via `Get.back()`.
  static Future<T?> custom<T>({
    required String title,
    required Widget content,
    List<Widget>? actions,
    double maxWidth = 480,
  }) => Get.dialog<T>(
    _AppDialogShell(
      title: title,
      content: content,
      actions: actions,
      maxWidth: maxWidth,
    ),
  );
}

class _AppDialogShell extends StatelessWidget {
  const _AppDialogShell({
    required this.title,
    required this.content,
    this.icon,
    this.iconColor,
    this.actions,
    this.maxWidth = 420,
  });

  final String title;
  final Widget content;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, color: iconColor, size: 22),
                    AppSpacing.hGapSm,
                  ],
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineMedium),
                  ),
                ],
              ),
              AppSpacing.gapLg,
              Flexible(child: SingleChildScrollView(child: content)),
              if (actions != null) ...<Widget>[
                AppSpacing.gapXl,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
