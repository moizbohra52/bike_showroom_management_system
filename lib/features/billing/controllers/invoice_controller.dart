import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/features/billing/repositories/invoice_repository.dart';
import 'package:get/get.dart';

/// Drives the invoice list for the active showroom.
class InvoiceController extends ListController<InvoiceModel> {
  InvoiceController({required InvoiceRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['invoice_number'],
      );

  final Rxn<InvoiceStatus> statusFilter = Rxn<InvoiceStatus>();

  void filterByStatus(InvoiceStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }

  /// Only invoices with money still owing — what a collections call works
  /// from.
  void showOutstandingOnly() {
    statusFilter.value = null;
    params.value = params.value
        .withFilter(
          const QueryFilter.greaterOrEqual('outstanding_amount', 0.01),
        )
        .resetPage();
    reload();
  }

  void filterByDateRange(DateRange? range) =>
      setDateRange(range, dateColumn: 'invoice_date');
}

/// Loads one invoice with its lines, for the printable view.
class InvoiceDetailsController extends GetxController {
  InvoiceDetailsController({
    required this.invoiceRepository,
    required this.invoice,
  });

  final InvoiceRepository invoiceRepository;

  /// The list's row, shown while the full record loads so the screen is never
  /// blank.
  final InvoiceModel invoice;

  late final Rx<InvoiceModel> detail = invoice.obs;

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
      detail.value = await invoiceRepository.getDetail(invoice.id);
    } on Object catch (e, stackTrace) {
      final AppException mapped = ErrorMapper.map(e, stackTrace);
      error.value = mapped;
      AppSnackbar.fromException(mapped);
    } finally {
      isLoading.value = false;
    }
  }
}
