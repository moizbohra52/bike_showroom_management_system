import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/accounting/models/account_model.dart';
import 'package:bike_showroom_management_system/features/accounting/models/journal_entry_model.dart';
import 'package:bike_showroom_management_system/features/accounting/repositories/account_repository.dart';
import 'package:bike_showroom_management_system/features/accounting/repositories/journal_repository.dart';
import 'package:get/get.dart';

/// Drives the chart of accounts and the trial balance for the active branch.
class AccountingController extends GetxController {
  AccountingController({required this.accountRepository});

  final AccountRepository accountRepository;

  final RxList<AccountModel> accounts = <AccountModel>[].obs;
  final RxList<TrialBalanceRow> trialBalance = <TrialBalanceRow>[].obs;

  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AccountType> typeFilter = Rxn<AccountType>();

  String? get showroomId =>
      Get.find<SessionController>().activeShowroomId.value;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    final String? id = showroomId;
    if (id == null) {
      // A super admin with no branch selected has no single chart to show —
      // the codes are identical everywhere, but the balances are not.
      error.value = BusinessRuleException(
        message: 'Select a showroom to see its chart of accounts.',
      );
      return;
    }

    isLoading.value = true;
    error.value = null;
    try {
      accounts.assignAll(await accountRepository.listChart(id));
      trialBalance.assignAll(await accountRepository.trialBalance(id));
    } on Object catch (e, stackTrace) {
      final AppException mapped = ErrorMapper.map(e, stackTrace);
      error.value = mapped;
      AppSnackbar.fromException(mapped);
    } finally {
      isLoading.value = false;
    }
  }

  void filterByType(AccountType? type) => typeFilter.value = type;

  List<AccountModel> get visibleAccounts {
    final AccountType? type = typeFilter.value;
    if (type == null) {
      return accounts;
    }
    return accounts
        .where((AccountModel a) => a.accountType == type)
        .toList(growable: false);
  }

  /// Rows that have actually been posted to.
  ///
  /// A freshly provisioned branch has forty accounts and no activity; showing
  /// forty zero rows buries the handful that matter.
  List<TrialBalanceRow> get activeTrialBalance => trialBalance
      .where((TrialBalanceRow r) => r.hasActivity)
      .toList(growable: false);

  double get totalDebit => trialBalance.fold<double>(
    0,
    (double sum, TrialBalanceRow r) => sum + r.totalDebit,
  );

  double get totalCredit => trialBalance.fold<double>(
    0,
    (double sum, TrialBalanceRow r) => sum + r.totalCredit,
  );

  /// The check the whole double-entry system exists to satisfy.
  bool get isBalanced => (totalDebit - totalCredit).abs() <= 0.01;
}

/// Drives the journal — every posting, newest first.
class JournalController extends ListController<JournalEntryModel> {
  JournalController({required JournalRepository repository})
    : super(
        repository: repository,
        // `accounting_transactions` has no searchable identifier of its own;
        // the description is free text written by the posting function, so
        // filtering is by reference type and date instead.
        searchColumns: const <String>['description'],
      );

  final Rxn<AccountingReferenceType> referenceFilter =
      Rxn<AccountingReferenceType>();

  void filterByReference(AccountingReferenceType? type) {
    referenceFilter.value = type;
    if (type == null) {
      removeFilter('reference_type');
    } else {
      applyFilter(QueryFilter.equals('reference_type', type.value));
    }
  }

  void filterByDateRange(DateRange? range) =>
      setDateRange(range, dateColumn: 'transaction_date');
}
