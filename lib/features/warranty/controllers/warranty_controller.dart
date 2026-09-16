import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/warranty/models/warranty_model.dart';
import 'package:bike_showroom_management_system/features/warranty/repositories/warranty_repository.dart';
import 'package:get/get.dart';

/// Drives the warranty list for the active showroom.
class WarrantyController extends ListController<WarrantyModel> {
  WarrantyController({required WarrantyRepository repository})
    : super(
        // `warranties` carries no searchable text of its own — the
        // registration number lives on the embedded vehicle, and PostgREST
        // cannot `or()` across an embed. Filtering is by type, status and
        // expiry instead.
        repository: repository,
        searchColumns: const <String>[],
      );

  final Rxn<WarrantyStatus> statusFilter = Rxn<WarrantyStatus>();
  final Rxn<WarrantyType> typeFilter = Rxn<WarrantyType>();

  void filterByStatus(WarrantyStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }

  void filterByType(WarrantyType? type) {
    typeFilter.value = type;
    if (type == null) {
      removeFilter('warranty_type');
    } else {
      applyFilter(QueryFilter.equals('warranty_type', type.value));
    }
  }

  /// Cover that has lapsed or is about to — the renewal call list.
  void showExpiring() {
    statusFilter.value = null;
    typeFilter.value = null;
    params.value = params.value
        .withFilter(
          QueryFilter.inList('status', <String>[
            WarrantyStatus.expiringSoon.value,
            WarrantyStatus.expired.value,
          ]),
        )
        .resetPage();
    reload();
  }

  void filterByExpiry(DateRange? range) =>
      setDateRange(range, dateColumn: 'end_date');
}

/// Drives the claim list and raising a new claim.
class WarrantyClaimController extends ListController<WarrantyClaimModel> {
  WarrantyClaimController({
    required WarrantyClaimRepository repository,
    required this.warrantyRepository,
  }) : super(
         repository: repository,
         searchColumns: const <String>['claim_number', 'description'],
       );

  final WarrantyRepository warrantyRepository;

  WarrantyClaimRepository get claimRepository =>
      repository as WarrantyClaimRepository;

  final Rxn<WarrantyClaimStatus> statusFilter = Rxn<WarrantyClaimStatus>();
  final RxBool isSaving = false.obs;

  void filterByStatus(WarrantyClaimStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }

  /// Raises a claim against [warranty].
  ///
  /// Refused for cover that has lapsed or been voided — the server would let
  /// the row be written, but a claim against nothing is a claim that has to be
  /// rejected later, so it is stopped here.
  Future<bool> raise({
    required WarrantyModel warranty,
    required String description,
    required double claimAmount,
  }) async {
    final SessionController session = Get.find<SessionController>();
    if (!session.can(AppPermissions.warrantyClaim)) {
      AppSnackbar.error('You do not have permission to raise a claim.');
      return false;
    }
    if (!warranty.acceptsClaim) {
      AppSnackbar.error(
        'This warranty has ${warranty.isVoided ? "been voided" : "expired"}, '
        'so it covers nothing.',
      );
      return false;
    }
    if (description.trim().isEmpty) {
      AppSnackbar.error('Describe the fault being claimed for.');
      return false;
    }

    isSaving.value = true;
    try {
      await claimRepository.create(<String, Object?>{
        'showroom_id': warranty.showroomId,
        'warranty_id': warranty.id,
        'claim_number': await claimRepository.nextClaimNumber(
          warranty.showroomId,
        ),
        'claim_date': DateUtil.toIsoDate(DateTime.now()),
        'description': description.trim(),
        'claim_amount': claimAmount,
        'status': WarrantyClaimStatus.submitted.value,
      });
      AppSnackbar.success('Claim submitted.');
      await reload();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Records the manufacturer's decision.
  ///
  /// [approvedAmount] is what they actually allowed, which is frequently less
  /// than was claimed; the difference is what the showroom absorbs.
  Future<bool> settle({
    required WarrantyClaimModel claim,
    required WarrantyClaimStatus status,
    double? approvedAmount,
    String? resolution,
  }) async {
    if (!Get.find<SessionController>().can(AppPermissions.warrantyApprove)) {
      AppSnackbar.error('You do not have permission to settle a claim.');
      return false;
    }

    isSaving.value = true;
    try {
      final String? trimmedResolution = resolution?.trim();
      await claimRepository.update(claim.id, <String, Object?>{
        'status': status.value,
        'approved_amount': ?approvedAmount,
        if (trimmedResolution != null && trimmedResolution.isNotEmpty)
          'resolution': trimmedResolution,
      }, expectedRevision: claim.revision);
      AppSnackbar.success('Claim marked ${status.label.toLowerCase()}.');
      await reload();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
