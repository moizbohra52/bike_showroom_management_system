import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/features/auth/models/app_user_model.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:bike_showroom_management_system/features/roles/repositories/role_repository.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/features/showroom/repositories/showroom_repository.dart';
import 'package:bike_showroom_management_system/features/users/repositories/user_repository.dart';
import 'package:get/get.dart';

/// Assigns roles and showrooms to a user — the "controlled onboarding" step
/// the specification requires after the auth trigger creates a bare profile
/// (§83): a new account can authenticate but reaches nothing useful until an
/// administrator completes this screen.
///
/// Every add/remove is issued immediately against `user_roles` /
/// `user_showrooms` rather than batched behind a Save button. There is no
/// multi-field form validity to protect here — each toggle is independently
/// meaningful and RLS re-authorises every one of them regardless — so
/// immediate feedback (a toast per change) is more informative than a single
/// bulk save that could partially fail.
class UserAssignmentController extends GetxController {
  UserAssignmentController({
    required this.userRepository,
    required this.roleRepository,
    required this.showroomRepository,
    required this.user,
  });

  final UserRepository userRepository;
  final RoleRepository roleRepository;
  final ShowroomRepository showroomRepository;

  AppUserModel user;

  final RxBool isLoading = true.obs;
  final RxList<RoleModel> allRoles = <RoleModel>[].obs;
  final RxList<ShowroomModel> allShowrooms = <ShowroomModel>[].obs;

  /// Ids currently busy, so a row can show its own spinner rather than
  /// locking the whole screen while one toggle is in flight.
  final RxSet<String> pendingIds = <String>{}.obs;

  Set<String> get heldRoleIds => user.roles.map((RoleModel r) => r.id).toSet();

  Set<String> get heldShowroomIds => user.accessibleShowroomIds.toSet();

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      final List<RoleModel> roles = await roleRepository.listAll(
        QueryParams(pageSize: 200),
      );
      final List<ShowroomModel> showrooms = await showroomRepository.listAll(
        QueryParams(pageSize: 200),
      );
      roles.sort((RoleModel a, RoleModel b) => a.rank.compareTo(b.rank));
      showrooms.sort(
        (ShowroomModel a, ShowroomModel b) => a.name.compareTo(b.name),
      );
      allRoles.assignAll(roles);
      allShowrooms.assignAll(showrooms);

      // Re-fetch the user with fresh embeds so a previous partial load (or a
      // stale list-screen copy) does not show as out of date the moment this
      // screen opens.
      user = await userRepository.getById(user.id);
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleRole(RoleModel role, {required bool grant}) async {
    if (role.isSuperAdmin && !grant) {
      // Refusing client-side too, so the attempt never reaches the server:
      // a system with zero super admins can lock everyone out of the ability
      // to grant one back in.
      AppSnackbar.error(
        'Cannot remove the SUPER ADMIN role through this screen.',
      );
      return;
    }

    pendingIds.add(role.id);
    try {
      if (grant) {
        await userRepository.addRole(user.id, role.id);
      } else {
        await userRepository.removeRole(user.id, role.id);
      }
      user = await userRepository.getById(user.id);
      AppSnackbar.success(
        grant ? '${role.label} granted.' : '${role.label} removed.',
      );
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      pendingIds.remove(role.id);
    }
  }

  Future<void> toggleShowroom(
    ShowroomModel showroom, {
    required bool grant,
  }) async {
    if (!grant && showroom.id == user.showroomId) {
      AppSnackbar.error(
        'This is the user\'s home showroom. Change their home showroom in '
        'their profile instead of removing it here.',
      );
      return;
    }

    pendingIds.add(showroom.id);
    try {
      if (grant) {
        await userRepository.addShowroom(user.id, showroom.id);
      } else {
        await userRepository.removeShowroom(user.id, showroom.id);
      }
      user = await userRepository.getById(user.id);
      AppSnackbar.success(
        grant ? '${showroom.name} added.' : '${showroom.name} removed.',
      );
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      pendingIds.remove(showroom.id);
    }
  }
}
