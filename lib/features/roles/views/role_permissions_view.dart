import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/roles/controllers/role_controller.dart';
import 'package:bike_showroom_management_system/features/roles/models/permission_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The permission matrix: every module in the catalogue, each action within
/// it shown as a checkbox reflecting whether this role currently grants it.
///
/// Changes are held in memory and submitted as one atomic replace on Save
/// (see [RoleRepository.setPermissions]) rather than one request per
/// checkbox, so toggling ten boxes does not fire ten network calls and a
/// half-finished edit is never partially applied.
class RolePermissionsView extends GetView<RolePermissionsController> {
  const RolePermissionsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Permissions - ${controller.role.label}')),
    body: Obx(() {
      if (controller.isLoading.value) {
        return const AppLoader(message: 'Loading permission catalogue...');
      }

      return Column(
        children: <Widget>[
          if (controller.isSuperAdmin) _SuperAdminBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: context.pagePadding,
              child: AppContentContainer(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final String module
                        in controller.catalogueByModule.keys.toList()..sort())
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ModuleSection(module: module),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }),
    bottomNavigationBar: controller.isSuperAdmin
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  AppButton.ghost(label: 'Cancel', onPressed: Get.back),
                  const Spacer(),
                  Obx(
                    () => AppButton.primary(
                      label: 'Save permissions',
                      isLoading: controller.isSaving.value,
                      onPressed: () async {
                        final bool saved = await controller.save();
                        if (saved) {
                          Get.back(result: true);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}

class _SuperAdminBanner extends StatelessWidget {
  const _SuperAdminBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.infoSurface,
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: <Widget>[
        const Icon(Icons.info_outline, size: 18, color: AppColors.info),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(
            'SUPER ADMIN implicitly holds every permission and cannot be '
            'edited here.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.info),
          ),
        ),
      ],
    ),
  );
}

class _ModuleSection extends StatelessWidget {
  const _ModuleSection({required this.module});

  final String module;

  String _titleCase(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  @override
  Widget build(BuildContext context) {
    final RolePermissionsController controller =
        Get.find<RolePermissionsController>();

    return Obx(() {
      final List<PermissionModel> permissions =
          controller.catalogueByModule[module] ?? const <PermissionModel>[];
      final bool fullyChecked = controller.isModuleFullyChecked(module);
      final bool partiallyChecked = controller.isModulePartiallyChecked(module);

      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Checkbox(
                  value: fullyChecked
                      ? true
                      : (partiallyChecked ? null : false),
                  tristate: true,
                  onChanged: controller.isSuperAdmin
                      ? null
                      : (bool? value) => controller.toggleModule(
                          module,
                          value: value ?? false,
                        ),
                ),
                Text(
                  _titleCase(module),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final PermissionModel permission in permissions)
                  _PermissionChip(permission: permission),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.permission});

  final PermissionModel permission;

  @override
  Widget build(BuildContext context) {
    final RolePermissionsController controller =
        Get.find<RolePermissionsController>();

    return Obx(() {
      final bool checked = controller.isChecked(permission);
      return FilterChip(
        label: Text(permission.action),
        selected: checked,
        tooltip: permission.description,
        onSelected: controller.isSuperAdmin
            ? null
            : (bool value) => controller.toggle(permission, value: value),
      );
    });
  }
}
