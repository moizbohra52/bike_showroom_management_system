import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/features/emi/models/emi_schedule_model.dart';
import 'package:bike_showroom_management_system/features/emi/repositories/emi_repository.dart';
import 'package:bike_showroom_management_system/features/finance/models/finance_company_model.dart';
import 'package:bike_showroom_management_system/features/finance/models/loan_model.dart';
import 'package:bike_showroom_management_system/features/finance/repositories/finance_company_repository.dart';
import 'package:bike_showroom_management_system/features/finance/repositories/loan_repository.dart';
import 'package:get/get.dart';

/// Drives the finance-company list.
///
/// Not showroom-scoped: financiers are shared across branches, so narrowing
/// the list would hide a company another branch places loans with.
class FinanceCompanyController extends ListController<FinanceCompanyModel> {
  FinanceCompanyController({required FinanceCompanyRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['name', 'code', 'contact_person'],
      );

  @override
  bool get scopeToActiveShowroom => false;

  FinanceCompanyRepository get _repository =>
      repository as FinanceCompanyRepository;

  final RxBool isSaving = false.obs;

  /// Creates or renames a financier. Returns true on success; the dialog stays
  /// open on failure so nothing typed is lost.
  Future<bool> save({
    required String name,
    required String code,
    FinanceCompanyModel? existing,
  }) async {
    final String permission = existing == null
        ? AppPermissions.financeCreate
        : AppPermissions.financeEdit;
    if (!Get.find<SessionController>().can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return false;
    }
    if (name.trim().isEmpty || code.trim().isEmpty) {
      AppSnackbar.error('Enter a name and a short code.');
      return false;
    }

    isSaving.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
      };
      if (existing == null) {
        await _repository.create(payload);
        AppSnackbar.success('Finance company added.');
      } else {
        await _repository.update(
          existing.id,
          payload,
          expectedRevision: existing.revision,
        );
        AppSnackbar.success('Finance company updated.');
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

  Future<void> toggleStatus(FinanceCompanyModel company) async {
    final RecordStatus next = company.isActive
        ? RecordStatus.inactive
        : RecordStatus.active;
    try {
      await _repository.update(company.id, <String, Object?>{
        'status': next.value,
      });
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }
}

/// Drives the loan list for the active showroom.
class LoanController extends ListController<LoanModel> {
  LoanController({required LoanRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['loan_number'],
      );

  final Rxn<LoanStatus> statusFilter = Rxn<LoanStatus>();

  void filterByStatus(LoanStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }
}

/// Loads one loan together with its full repayment schedule.
class LoanDetailsController extends GetxController {
  LoanDetailsController({required this.emiRepository, required this.loan});

  final EmiRepository emiRepository;

  final LoanModel loan;

  final RxList<EmiScheduleModel> schedule = <EmiScheduleModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      schedule.assignAll(await emiRepository.listForLoan(loan.id));
    } on Object catch (e, stackTrace) {
      final AppException mapped = ErrorMapper.map(e, stackTrace);
      error.value = mapped;
      AppSnackbar.fromException(mapped);
    } finally {
      isLoading.value = false;
    }
  }

  /// How much of the agreement has actually been collected.
  double get totalPaid => schedule.fold<double>(
    0,
    (double sum, EmiScheduleModel emi) => sum + emi.paidAmount,
  );

  /// What remains, penalties included — the figure a collections call quotes.
  double get totalOutstanding => schedule.fold<double>(
    0,
    (double sum, EmiScheduleModel emi) => sum + emi.amountDue,
  );

  int get paidCount =>
      schedule.where((EmiScheduleModel emi) => emi.isPaid).length;

  int get overdueCount =>
      schedule.where((EmiScheduleModel emi) => emi.isOverdue).length;
}
