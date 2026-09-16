import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_category_model.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_model.dart';
import 'package:bike_showroom_management_system/features/expenses/repositories/expense_category_repository.dart';
import 'package:bike_showroom_management_system/features/expenses/repositories/expense_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the expense list for the active showroom.
class ExpenseController extends ListController<ExpenseModel> {
  ExpenseController({required ExpenseRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>[
          'expense_number',
          'vendor_name',
          'reference_number',
        ],
      );

  ExpenseRepository get _repository => repository as ExpenseRepository;

  final Rxn<ExpenseStatus> statusFilter = Rxn<ExpenseStatus>();
  final RxBool isDeciding = false.obs;

  /// The signed-in user, so the list can tell whose expenses they may decide.
  String? get currentUserId => Get.find<SessionController>().userId;

  /// A super admin is exempt from the self-approval rule, matching
  /// `approve_expense`.
  bool get isSuperAdmin => Get.find<SessionController>().isSuperAdmin;

  void filterByStatus(ExpenseStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }

  void filterByDateRange(DateRange? range) =>
      setDateRange(range, dateColumn: 'expense_date');

  /// Everything awaiting a decision — the approval queue.
  void showPendingApproval() {
    statusFilter.value = ExpenseStatus.pending;
    applyFilter(
      QueryFilter.equals(DbColumns.status, ExpenseStatus.pending.value),
    );
  }

  /// Approves or rejects an expense through the RPC.
  Future<bool> decide({
    required ExpenseModel expense,
    required bool approve,
    String? reason,
  }) async {
    final SessionController session = Get.find<SessionController>();
    final String permission = approve
        ? AppPermissions.expensesApprove
        : AppPermissions.expensesReject;
    if (!session.can(permission)) {
      AppSnackbar.error(
        approve
            ? 'You do not have permission to approve an expense.'
            : 'You do not have permission to reject an expense.',
      );
      return false;
    }

    isDeciding.value = true;
    try {
      await _repository.decide(
        expenseId: expense.id,
        approve: approve,
        reason: reason,
      );
      AppSnackbar.success(approve ? 'Expense approved.' : 'Expense rejected.');
      await reload();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isDeciding.value = false;
    }
  }
}

/// Records a new expense.
class ExpenseFormController extends GetxController {
  ExpenseFormController({
    required this.expenseRepository,
    required this.categoryRepository,
  });

  final ExpenseRepository expenseRepository;
  final ExpenseCategoryRepository categoryRepository;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController taxAmountController = TextEditingController();
  final TextEditingController vendorController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final Rxn<String> categoryId = Rxn<String>();
  final Rxn<DateTime> expenseDate = Rxn<DateTime>(DateTime.now());
  final Rx<PaymentMethod> paymentMethod = PaymentMethod.cash.obs;

  final RxList<ExpenseCategoryModel> categories = <ExpenseCategoryModel>[].obs;
  final RxBool isLoadingCategories = false.obs;
  final RxBool isSubmitting = false.obs;

  String? get showroomId =>
      Get.find<SessionController>().activeShowroomId.value;

  bool get requiresReference =>
      paymentMethod.value != PaymentMethod.cash &&
      paymentMethod.value != PaymentMethod.mixed;

  /// The category chosen, when it is one of the loaded options.
  ExpenseCategoryModel? get selectedCategory {
    final String? id = categoryId.value;
    if (id == null) {
      return null;
    }
    for (final ExpenseCategoryModel category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  /// Net amount plus the tax entered — what the total will be.
  double get total =>
      _numberOf(amountController) + _numberOf(taxAmountController);

  @override
  void onInit() {
    super.onInit();
    unawaited(loadCategories());
  }

  Future<void> loadCategories() async {
    isLoadingCategories.value = true;
    try {
      categories.assignAll(await categoryRepository.listActive());
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingCategories.value = false;
    }
  }

  String? validateAmount(String? value) =>
      AppValidators.amount(value, field: 'Amount');

  String? validateTaxAmount(String? value) =>
      AppValidators.amount(value, isRequired: false, allowZero: true);

  String? validateReference(String? value) =>
      AppValidators.paymentReference(value, isRequired: requiresReference);

  Future<String?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }
    if (categoryId.value == null) {
      AppSnackbar.error('Select a category.');
      return null;
    }

    final SessionController session = Get.find<SessionController>();
    if (!session.can(AppPermissions.expensesCreate)) {
      AppSnackbar.error('You do not have permission to record an expense.');
      return null;
    }
    final String? id = showroomId;
    if (id == null) {
      AppSnackbar.error('Select a showroom before recording an expense.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final String expenseId = await expenseRepository
          .createExpense(<String, Object?>{
            'showroom_id': id,
            'category_id': categoryId.value,
            'amount': _numberOf(amountController),
            'tax_amount': _numberOf(taxAmountController),
            'expense_date': DateUtil.toIsoDateOrNull(expenseDate.value),
            'payment_method': paymentMethod.value.value,
            if (vendorController.text.trim().isNotEmpty)
              'vendor_name': vendorController.text.trim(),
            if (referenceController.text.trim().isNotEmpty)
              'reference_number': referenceController.text.trim(),
            if (descriptionController.text.trim().isNotEmpty)
              'description': descriptionController.text.trim(),
          });
      AppSnackbar.success('Expense recorded and sent for approval.');
      return expenseId;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  double _numberOf(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  @override
  void onClose() {
    amountController.dispose();
    taxAmountController.dispose();
    vendorController.dispose();
    referenceController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}

/// Drives the expense-category list.
class ExpenseCategoryController extends ListController<ExpenseCategoryModel> {
  ExpenseCategoryController({required ExpenseCategoryRepository repository})
    : super(repository: repository, searchColumns: const <String>['name']);

  @override
  bool get scopeToActiveShowroom => false;

  ExpenseCategoryRepository get _repository =>
      repository as ExpenseCategoryRepository;

  final RxBool isSaving = false.obs;

  Future<bool> save({
    required String name,
    String? accountCode,
    ExpenseCategoryModel? existing,
  }) async {
    if (!Get.find<SessionController>().can(AppPermissions.accountingManage)) {
      // A category decides which account an expense posts to, so changing the
      // list is an accounting act rather than an expenses one.
      AppSnackbar.error('You do not have permission to manage categories.');
      return false;
    }
    if (name.trim().isEmpty) {
      AppSnackbar.error('Enter a category name.');
      return false;
    }

    isSaving.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'name': name.trim(),
        'account_code': accountCode == null || accountCode.trim().isEmpty
            ? null
            : accountCode.trim(),
      };
      if (existing == null) {
        await _repository.create(payload);
        AppSnackbar.success('Category added.');
      } else {
        await _repository.update(existing.id, payload);
        AppSnackbar.success('Category updated.');
      }
      await reload();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> toggleActive(ExpenseCategoryModel category) async {
    try {
      // Retired, not deleted: expenses already booked under it must stay
      // resolvable.
      await _repository.update(category.id, <String, Object?>{
        'is_active': !category.isActive,
      });
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }
}
