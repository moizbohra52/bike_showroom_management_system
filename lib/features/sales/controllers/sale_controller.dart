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
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';
import 'package:bike_showroom_management_system/features/sales/repositories/sale_repository.dart';
import 'package:get/get.dart';

/// Drives the sales list for the active showroom.
class SaleController extends ListController<SaleModel> {
  SaleController({required SaleRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['sale_number'],
      );

  final Rxn<SaleStatus> statusFilter = Rxn<SaleStatus>();
  final Rxn<SaleType> typeFilter = Rxn<SaleType>();

  void filterByStatus(SaleStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }

  void filterByType(SaleType? type) {
    typeFilter.value = type;
    if (type == null) {
      removeFilter('sale_type');
    } else {
      applyFilter(QueryFilter.equals('sale_type', type.value));
    }
  }

  void filterByDateRange(DateRange? range) =>
      setDateRange(range, dateColumn: 'sale_date');
}

/// Loads one sale with its line items, and owns the cancel action.
class SaleDetailsController extends GetxController {
  SaleDetailsController({required this.saleRepository, required this.sale});

  final SaleRepository saleRepository;

  /// The row the list already had. Shown immediately while the full record,
  /// with its line items, is fetched — the screen is never blank.
  final SaleModel sale;

  final Rx<SaleModel> detail = SaleModel(
    id: '',
    showroomId: '',
    customerId: '',
    saleNumber: '',
    saleDate: DateTime.now(),
  ).obs;

  final RxBool isLoading = false.obs;
  final RxBool isCancelling = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  @override
  void onInit() {
    super.onInit();
    detail.value = sale;
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      detail.value = await saleRepository.getDetail(sale.id);
    } on Object catch (e, stackTrace) {
      final AppException mapped = ErrorMapper.map(e, stackTrace);
      error.value = mapped;
      AppSnackbar.fromException(mapped);
    } finally {
      isLoading.value = false;
    }
  }

  /// Cancels the sale through the RPC, which also returns the stock, reverses
  /// the ledger and voids the invoice.
  Future<bool> cancel(String reason) async {
    if (!Get.find<SessionController>().can(AppPermissions.salesCancel)) {
      AppSnackbar.error('You do not have permission to cancel a sale.');
      return false;
    }

    isCancelling.value = true;
    try {
      await saleRepository.cancelSale(saleId: sale.id, reason: reason);
      AppSnackbar.success('Sale cancelled and stock returned.');
      await load();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isCancelling.value = false;
    }
  }
}
