import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/config/supabase_config.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:bike_showroom_management_system/features/roles/repositories/role_repository.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/features/showroom/repositories/showroom_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Invites a brand-new person into the system.
///
/// ## Why this needs an Edge Function
///
/// Creating an auth account *for someone else* cannot be done with the
/// regular client SDK: `auth.signUp()` both creates the account and signs
/// the caller in as it, which would hijack the administrator's own session.
/// The operation that can do this — `auth.admin.createUser()` /
/// `inviteUserByEmail()` — requires the service-role key, and that key must
/// never reach a Flutter client (§31, §40): anyone who obtained it could
/// bypass Row Level Security for every showroom in the system.
///
/// The only place that key may live is a server-side Edge Function. This
/// controller calls `invite-user` (source at
/// `supabase/functions/invite-user/index.ts`) through the existing
/// [ApiClient.invokeFunction], which forwards the *caller's* access token —
/// the function independently re-checks `users.create` / `users.assign`
/// before touching anything, exactly like every SECURITY DEFINER SQL
/// function in this project re-checks its own authorisation rather than
/// trusting the privilege its elevated credentials happen to carry.
class UserInviteController extends GetxController {
  UserInviteController({
    required this.roleRepository,
    required this.showroomRepository,
  });

  final RoleRepository roleRepository;
  final ShowroomRepository showroomRepository;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController employeeCodeController = TextEditingController();

  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxList<RoleModel> assignableRoles = <RoleModel>[].obs;
  final RxList<ShowroomModel> assignableShowrooms = <ShowroomModel>[].obs;

  final Rxn<RoleModel> selectedRole = Rxn<RoleModel>();
  final Rxn<ShowroomModel> selectedShowroom = Rxn<ShowroomModel>();

  @override
  void onInit() {
    super.onInit();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    isLoading.value = true;
    try {
      final List<RoleModel> roles =
          await roleRepository.listAll(QueryParams(pageSize: 200))
            ..removeWhere((RoleModel role) => role.isSuperAdmin);
      final List<ShowroomModel> showrooms = await showroomRepository.listAll(
        QueryParams(pageSize: 200),
      );

      roles.sort((RoleModel a, RoleModel b) => a.rank.compareTo(b.rank));
      showrooms.sort(
        (ShowroomModel a, ShowroomModel b) => a.name.compareTo(b.name),
      );
      assignableRoles.assignAll(roles);
      assignableShowrooms.assignAll(showrooms);
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoading.value = false;
    }
  }

  String? validateName(String? value) =>
      AppValidators.name(value, field: 'Name');

  String? validateEmail(String? value) => AppValidators.email(value);

  String? validatePhone(String? value) => AppValidators.alternatePhone(value);

  String? validateRole(RoleModel? value) =>
      value == null ? 'Please choose a role' : null;

  String? validateShowroom(ShowroomModel? value) =>
      value == null ? 'Please choose a showroom' : null;

  Future<bool> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return false;
    }
    if (selectedRole.value == null || selectedShowroom.value == null) {
      // The Form only validates text fields; the two dropdowns are checked
      // explicitly since they are not TextFormFields.
      AppSnackbar.error('Please choose a role and a showroom.');
      return false;
    }

    isSubmitting.value = true;
    try {
      final Object result = await SupabaseConfig.client.functions.invoke(
        'invite-user',
        body: <String, Object?>{
          'name': nameController.text.trim(),
          'email': emailController.text.trim().toLowerCase(),
          'phone': phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          'employee_code': employeeCodeController.text.trim().isEmpty
              ? null
              : employeeCodeController.text.trim(),
          'showroom_id': selectedShowroom.value!.id,
          'role_id': selectedRole.value!.id,
        },
      );

      // The function returns {"error": "..."} on a handled failure (a
      // duplicate email, for instance) with a 4xx status that
      // FunctionsClient surfaces as data rather than throwing.
      if (result is Map && result['error'] != null) {
        AppSnackbar.error(result['error'].toString());
        return false;
      }

      AppSnackbar.success(
        '${nameController.text.trim()} has been invited. They will receive '
        'an email to set their password.',
      );
      return true;
    } on AppException catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } on Object catch (e, stackTrace) {
      AppSnackbar.fromException(ErrorMapper.map(e, stackTrace));
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    employeeCodeController.dispose();
    super.onClose();
  }
}
