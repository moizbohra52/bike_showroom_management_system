import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/auth/models/auth_context.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:bike_showroom_management_system/services/auth_service.dart';
import 'package:bike_showroom_management_system/services/storage_service.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the sign-in, password-reset and sign-out flows.
///
/// Owns the form state for those screens and nothing else; the resolved
/// identity lives in [SessionController], which outlives this controller.
class AuthController extends GetxController {
  AuthController({
    required this.authService,
    required this.sessionController,
    required this.storageService,
  });

  final AuthService authService;
  final SessionController sessionController;
  final StorageService storageService;

  static AuthController get instance => Get.find<AuthController>();

  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> forgotFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> resetFormKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController forgotEmailController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final RxBool isSubmitting = false.obs;
  final RxBool rememberEmail = true.obs;

  /// Populated from a `ValidationException`'s field errors so a server-side
  /// rejection lands on the right field instead of in a toast.
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  /// Non-field error shown above the form, for a failed credential check.
  final RxnString formError = RxnString();

  final RxBool resetEmailSent = false.obs;

  StreamSubscription<AuthLifecycleEvent>? _lifecycleSubscription;

  @override
  void onInit() {
    super.onInit();

    final String? remembered = storageService.rememberedEmail;
    if (remembered != null && remembered.isNotEmpty) {
      emailController.text = remembered;
    }

    _lifecycleSubscription = authService.onLifecycleEvent.listen(
      _handleLifecycleEvent,
    );
  }

  void _handleLifecycleEvent(AuthLifecycleEvent event) {
    switch (event) {
      case AuthLifecycleEvent.signedOut:
        // Covers a sign-out triggered elsewhere: a spent refresh token, or the
        // user signing out on another tab of the web build.
        if (Get.currentRoute != AppRoutes.login) {
          sessionController.clear();
          Get.offAllNamed(AppRoutes.login);
        }
      case AuthLifecycleEvent.passwordRecovery:
        if (Get.currentRoute != AppRoutes.resetPassword) {
          Get.toNamed(AppRoutes.resetPassword);
        }
      case AuthLifecycleEvent.signedIn:
      case AuthLifecycleEvent.tokenRefreshed:
      case AuthLifecycleEvent.userUpdated:
        break;
    }
  }

  // ------------------------------------------------------------------ sign in

  Future<void> signIn() async {
    formError.value = null;
    fieldErrors.clear();

    if (!(loginFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (isSubmitting.value) {
      return;
    }

    isSubmitting.value = true;
    try {
      final AuthContext context = await authService.signInWithPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      // A valid credential is not sufficient. An account with no role, no
      // showroom, or a deactivated status must not hold a session, so it is
      // signed straight back out rather than parked on a blocked screen with
      // a live token.
      final String? issue = context.provisioningIssue;
      if (issue != null) {
        await authService.signOut();
        await sessionController.clear();
        formError.value = issue;
        AppLogger.warning(
          'Rejected sign-in for an unprovisioned account',
          tag: 'auth',
          context: <String, Object?>{'userId': context.user.id},
        );
        return;
      }

      await sessionController.establish(context);
      await authService.recordSignIn(context.user.id);

      if (rememberEmail.value) {
        await storageService.setRememberedEmail(emailController.text.trim());
      } else {
        await storageService.clearRememberedEmail();
      }

      passwordController.clear();

      AppSnackbar.success('Welcome back, ${context.user.name}.');
      await Get.offAllNamed(AppRoutes.dashboard);
    } on AppException catch (error) {
      _applyError(error);
    } on Object catch (error, stackTrace) {
      _applyError(ErrorMapper.map(error, stackTrace));
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Projects an error onto the form.
  ///
  /// Field errors go to their fields; a credential failure becomes a banner
  /// above the form rather than a toast, because the user needs to read it
  /// while retyping. Anything else falls through to the snackbar.
  void _applyError(AppException error) {
    if (error.hasFieldErrors) {
      fieldErrors.assignAll(error.fieldErrors!);
    }
    if (error is AuthenticationException) {
      formError.value = error.message;
      return;
    }
    if (error is ForbiddenException) {
      formError.value = error.message;
      return;
    }
    AppSnackbar.fromException(error);
  }

  // ----------------------------------------------------------- password reset

  Future<void> sendPasswordReset() async {
    formError.value = null;
    if (!(forgotFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (isSubmitting.value) {
      return;
    }

    isSubmitting.value = true;
    try {
      await authService.sendPasswordReset(email: forgotEmailController.text);
      resetEmailSent.value = true;
      // Deliberately non-specific: confirming whether the address exists would
      // let anyone enumerate registered users.
      AppSnackbar.success(
        'If that address is registered, a reset link is on its way.',
      );
    } on AppException catch (error) {
      _applyError(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> completePasswordReset() async {
    formError.value = null;
    if (!(resetFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (isSubmitting.value) {
      return;
    }

    isSubmitting.value = true;
    try {
      await authService.updatePassword(newPasswordController.text);
      newPasswordController.clear();
      confirmPasswordController.clear();

      AppSnackbar.success('Your password has been updated. Please sign in.');

      // Force a fresh sign-in with the new password rather than continuing on
      // the recovery session, which carries reduced context.
      await authService.signOut();
      await sessionController.clear();
      await Get.offAllNamed(AppRoutes.login);
    } on AppException catch (error) {
      _applyError(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  // ----------------------------------------------------------------- sign out

  Future<void> signOut({bool showConfirmation = true}) async {
    if (isSubmitting.value) {
      return;
    }
    isSubmitting.value = true;
    try {
      await authService.signOut();
      await sessionController.clear();
      emailController.text = storageService.rememberedEmail ?? '';
      passwordController.clear();

      if (showConfirmation) {
        AppSnackbar.info('You have been signed out.');
      }
      await Get.offAllNamed(AppRoutes.login);
    } finally {
      isSubmitting.value = false;
    }
  }

  // --------------------------------------------------------------- validators

  String? validateEmail(String? value) => AppValidators.email(value);

  /// Sign-in deliberately checks only that a password was entered.
  ///
  /// Applying the full strength policy here would tell an existing user their
  /// own working password is "invalid" after the policy tightens, and would
  /// leak the policy to an attacker before authentication.
  String? validateSignInPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  String? validateNewPassword(String? value) => AppValidators.password(value);

  String? validateConfirmPassword(String? value) =>
      AppValidators.confirmPassword(value, newPasswordController.text);

  @override
  void onClose() {
    _lifecycleSubscription?.cancel();
    emailController.dispose();
    passwordController.dispose();
    forgotEmailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
