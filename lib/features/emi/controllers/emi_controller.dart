import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/emi/models/emi_schedule_model.dart';
import 'package:bike_showroom_management_system/features/emi/repositories/emi_repository.dart';
import 'package:bike_showroom_management_system/features/payments/repositories/payment_repository.dart';
import 'package:get/get.dart';

/// Which slice of the EMI book the dashboard is showing.
enum EmiView {
  overdue('Overdue'),
  dueSoon('Due soon'),
  all('All outstanding');

  const EmiView(this.label);

  final String label;
}

/// Drives the EMI collections dashboard.
///
/// Scoping is unusual here and deliberate: `emi_schedules` has no
/// `showroom_id`, so the base class's showroom filter is switched off and the
/// branch is applied through the embedded loan instead. See [EmiRepository].
class EmiController extends ListController<EmiScheduleModel> {
  EmiController({
    required EmiRepository repository,
    required this.paymentRepository,
  }) : super(repository: repository, searchColumns: const <String>[]);

  final PaymentRepository paymentRepository;

  @override
  bool get scopeToActiveShowroom => false;

  final Rx<EmiView> view = EmiView.overdue.obs;
  final RxBool isRecording = false.obs;

  String? get showroomId =>
      Get.find<SessionController>().activeShowroomId.value;

  @override
  void onInit() {
    _applyViewFilters(EmiView.overdue);
    super.onInit();
  }

  void showView(EmiView next) {
    view.value = next;
    _applyViewFilters(next);
    reload();
  }

  /// Rebuilds the filter set from scratch for [next].
  ///
  /// Rebuilt rather than adjusted because the three views overlap: switching
  /// from "overdue" to "due soon" has to drop the date bound the previous view
  /// added, and incrementally removing filters is how those get left behind.
  void _applyViewFilters(EmiView next) {
    final String? branch = showroomId;
    final List<QueryFilter> filters = <QueryFilter>[
      if (branch != null) EmiRepository.showroomFilter(branch),
    ];

    switch (next) {
      case EmiView.overdue:
        filters.add(QueryFilter.equals('status', EmiStatus.overdue.value));
      case EmiView.dueSoon:
        filters
          ..add(
            QueryFilter.inList('status', <String>[
              EmiStatus.upcoming.value,
              EmiStatus.due.value,
              EmiStatus.partial.value,
            ]),
          )
          ..add(
            QueryFilter.lessOrEqual(
              'due_date',
              DateUtil.toIsoDate(DateTime.now().add(const Duration(days: 14))),
            ),
          );
      case EmiView.all:
        filters.add(
          QueryFilter.inList(
            'status',
            EmiStatus.values
                .where((EmiStatus status) => status.isOutstanding)
                .map((EmiStatus status) => status.value)
                .toList(growable: false),
          ),
        );
    }

    params.value = params.value
        .copyWith(
          filters: filters,
          sorts: <QuerySort>[
            const QuerySort(
              column: 'due_date',
              direction: SortDirection.ascending,
            ),
          ],
        )
        .resetPage();
  }

  double get totalDue => response.value.items.fold<double>(
    0,
    (double sum, EmiScheduleModel emi) => sum + emi.amountDue,
  );

  int get overdueCount => response.value.items
      .where((EmiScheduleModel emi) => emi.isOverdue)
      .length;

  /// Records a collection against one instalment.
  ///
  /// Goes through `record_payment` with `allocation: EMI`, which updates the
  /// instalment, the loan and the ledger together. Writing `paid_amount`
  /// directly would leave the accounting untouched.
  Future<bool> recordEmiPayment({
    required EmiScheduleModel emi,
    required double amount,
    required PaymentMethod method,
    String? reference,
  }) async {
    final SessionController session = Get.find<SessionController>();
    if (!session.can(AppPermissions.emiPayment)) {
      AppSnackbar.error('You do not have permission to record an EMI payment.');
      return false;
    }

    final String? branch = showroomId;
    if (branch == null) {
      AppSnackbar.error('Select a showroom first.');
      return false;
    }

    isRecording.value = true;
    try {
      await paymentRepository.recordPayment(<String, Object?>{
        'showroom_id': branch,
        'emi_id': emi.id,
        'amount': amount,
        'payment_method': method.value,
        'allocation': PaymentAllocation.emi.value,
        'payment_date': DateUtil.toIsoDate(DateTime.now()),
        if (reference != null && reference.trim().isNotEmpty)
          'reference_number': reference.trim(),
      });
      AppSnackbar.success('EMI payment recorded.');
      await reload();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isRecording.value = false;
    }
  }
}
