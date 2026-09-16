import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dialog.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/auth/models/app_user_model.dart';
import 'package:bike_showroom_management_system/features/users/repositories/user_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the user list. A SUPER ADMIN sees every user across every
/// showroom; anyone else sees only users in the showrooms RLS lets them
/// reach, which is why this list — unlike most — does not further narrow to
/// just the *active* showroom: a regional manager assigned to three
/// branches should see staff across all three from one screen.
class UserController extends ListController<AppUserModel> {
  UserController({required UserRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>[
          'name',
          'email',
          'phone',
          'employee_code',
        ],
      );

  @override
  bool get scopeToActiveShowroom => false;

  UserRepository get _repository => repository as UserRepository;

  Future<void> toggleStatus(AppUserModel user) async {
    if (user.id == Get.find<SessionController>().userId) {
      AppSnackbar.error('You cannot deactivate your own account.');
      return;
    }

    final UserStatus next = user.isActive
        ? UserStatus.inactive
        : UserStatus.active;

    if (next == UserStatus.inactive) {
      final bool confirmed = await AppDialog.confirm(
        title: 'Deactivate user',
        message:
            '${user.name} will no longer be able to sign in. '
            'Their history is kept.',
        confirmLabel: 'Deactivate',
        isDestructive: true,
      );
      if (!confirmed) {
        return;
      }
    }

    try {
      await _repository.update(user.id, <String, Object?>{
        'status': next.value,
      });
      AppSnackbar.success(
        next.canSignIn ? 'User reactivated.' : 'User deactivated.',
      );
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }
}

/// Edits a user's profile fields. Never touches `auth_user_id`, `email` or
/// `status` — email changes flow through Supabase Auth (see
/// `handle_auth_user_updated()` in `015_auth_triggers.sql`), and status is a
/// dedicated action ([UserController.toggleStatus]) with its own
/// confirmation, not a field a form save should silently flip.
class UserFormController extends GetxController {
  UserFormController({required this.userRepository, required this.user});

  final UserRepository userRepository;
  final AppUserModel user;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController employeeCodeController = TextEditingController();
  final TextEditingController designationController = TextEditingController();
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    nameController.text = user.name;
    phoneController.text = user.phone ?? '';
    employeeCodeController.text = user.employeeCode ?? '';
    designationController.text = user.designation ?? '';
  }

  String? validateName(String? value) =>
      AppValidators.name(value, field: 'Name');

  String? validatePhone(String? value) => AppValidators.alternatePhone(value);

  Future<AppUserModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }

    isSubmitting.value = true;
    try {
      final AppUserModel saved = await userRepository
          .update(user.id, <String, Object?>{
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
            'employee_code': employeeCodeController.text.trim().isEmpty
                ? null
                : employeeCodeController.text.trim(),
            'designation': designationController.text.trim().isEmpty
                ? null
                : designationController.text.trim(),
          }, expectedRevision: user.revision);
      AppSnackbar.success('Profile updated.');
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
    phoneController.dispose();
    employeeCodeController.dispose();
    designationController.dispose();
    super.onClose();
  }
}
