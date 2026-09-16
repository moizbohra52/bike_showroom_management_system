import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dialog.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/roles/models/permission_model.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:bike_showroom_management_system/features/roles/repositories/role_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the role list. Roles are global (not scoped to a showroom), so
/// unlike most lists this one never filters by the active showroom.
class RoleController extends ListController<RoleModel> {
  RoleController({required RoleRepository repository})
    : super(repository: repository, searchColumns: const <String>['name']);

  @override
  bool get scopeToActiveShowroom => false;

  RoleRepository get _repository => repository as RoleRepository;

  Future<void> deleteRole(RoleModel role) async {
    if (role.isSystemRole) {
      AppSnackbar.error('System roles cannot be deleted.');
      return;
    }

    final bool confirmed = await AppDialog.confirm(
      title: 'Delete role',
      message:
          'Delete "${role.label}"? This cannot be undone. Any user '
          'still holding this role would need a new one assigned.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await _repository.delete(role.id);
      AppSnackbar.success('Role deleted.');
      await reload();
    } on Object catch (e) {
      // A role still assigned to a user is refused by the foreign-key
      // constraint on user_roles.role_id (ON DELETE RESTRICT), which
      // ErrorMapper turns into a friendly "linked to other data" message.
      AppSnackbar.fromException(e);
    }
  }
}

/// Owns the name/description form for creating or renaming a custom role.
/// Permission assignment is a separate screen ([RolePermissionsController])
/// because it has its own save action and its own loading state.
class RoleFormController extends GetxController {
  RoleFormController({required this.roleRepository, RoleModel? existing})
    : editing = existing;

  final RoleRepository roleRepository;
  final RoleModel? editing;

  bool get isEditing => editing != null;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    final RoleModel? source = editing;
    if (source != null) {
      nameController.text = source.name;
      descriptionController.text = source.description ?? '';
    }
  }

  String? validateName(String? value) =>
      AppValidators.name(value, field: 'Role name', maxLength: 60);

  Future<RoleModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }
    if (editing?.isSystemRole ?? false) {
      AppSnackbar.error('System roles cannot be renamed.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'name': nameController.text.trim().toUpperCase(),
        'description': descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      };

      final RoleModel saved = isEditing
          ? await roleRepository.update(editing!.id, payload)
          : await roleRepository.create(payload);

      AppSnackbar.success(isEditing ? 'Role updated.' : 'Role created.');
      return saved;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}

/// Owns the permission-matrix editor for one role: every permission in the
/// catalogue, grouped by module, with a checkbox reflecting whether the role
/// currently holds it.
class RolePermissionsController extends GetxController {
  RolePermissionsController({
    required this.roleRepository,
    required this.permissionRepository,
    required this.role,
  });

  final RoleRepository roleRepository;
  final PermissionRepository permissionRepository;
  final RoleModel role;

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;

  /// Every permission in the system, grouped by module and sorted, so the
  /// matrix renders in a stable, predictable order rather than however the
  /// server happened to return rows.
  final RxMap<String, List<PermissionModel>> catalogueByModule =
      <String, List<PermissionModel>>{}.obs;

  /// The permission ids currently checked. A plain in-memory set, submitted
  /// wholesale on Save rather than toggled one request at a time — see
  /// [RoleRepository.setPermissions] for why the replace itself is atomic.
  final RxSet<String> selectedPermissionIds = <String>{}.obs;

  bool get isSuperAdmin => role.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      final List<PermissionModel> all = await permissionRepository
          .listCatalogue();

      final Map<String, List<PermissionModel>> grouped =
          <String, List<PermissionModel>>{};
      for (final PermissionModel permission in all) {
        grouped
            .putIfAbsent(permission.module, () => <PermissionModel>[])
            .add(permission);
      }
      for (final List<PermissionModel> list in grouped.values) {
        list.sort(
          (PermissionModel a, PermissionModel b) =>
              a.action.compareTo(b.action),
        );
      }
      catalogueByModule.assignAll(grouped);

      selectedPermissionIds.assignAll(
        role.permissions.map((PermissionModel p) => p.id),
      );
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoading.value = false;
    }
  }

  bool isChecked(PermissionModel permission) =>
      isSuperAdmin || selectedPermissionIds.contains(permission.id);

  void toggle(PermissionModel permission, {required bool value}) {
    if (isSuperAdmin) {
      return;
    }
    if (value) {
      selectedPermissionIds.add(permission.id);
    } else {
      selectedPermissionIds.remove(permission.id);
    }
  }

  /// Checks or clears every permission in one module at once, for the
  /// "select all" row header.
  void toggleModule(String module, {required bool value}) {
    if (isSuperAdmin) {
      return;
    }
    final List<PermissionModel> permissions =
        catalogueByModule[module] ?? const <PermissionModel>[];
    if (value) {
      selectedPermissionIds.addAll(
        permissions.map((PermissionModel p) => p.id),
      );
    } else {
      selectedPermissionIds.removeAll(
        permissions.map((PermissionModel p) => p.id),
      );
    }
  }

  bool isModuleFullyChecked(String module) {
    final List<PermissionModel> permissions =
        catalogueByModule[module] ?? const <PermissionModel>[];
    return permissions.isNotEmpty &&
        permissions.every((PermissionModel p) => isChecked(p));
  }

  bool isModulePartiallyChecked(String module) {
    final List<PermissionModel> permissions =
        catalogueByModule[module] ?? const <PermissionModel>[];
    final bool anyChecked = permissions.any(
      (PermissionModel p) => isChecked(p),
    );
    return anyChecked && !isModuleFullyChecked(module);
  }

  Future<bool> save() async {
    if (isSuperAdmin) {
      AppSnackbar.info(
        'SUPER ADMIN implicitly holds every permission and cannot be edited.',
      );
      return false;
    }

    isSaving.value = true;
    try {
      await roleRepository.setPermissions(role.id, selectedPermissionIds);
      AppSnackbar.success('Permissions updated for ${role.label}.');
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
