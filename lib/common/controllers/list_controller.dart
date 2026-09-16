import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:get/get.dart';

/// Base state and behaviour for every paginated list screen.
///
/// Every list screen in the application — customers, inventory, sales,
/// invoices, and so on — needs the same handful of moving parts: a current
/// page of results, a loading flag, an error, search debouncing (handled by
/// [AppSearchField] itself), sort toggling, filter application and a page-size
/// change. Centralising them here means a bug fixed once (for instance, the
/// "stale response overwrites a newer one" race below) is fixed everywhere,
/// and a new list screen is a small subclass rather than a rewrite.
///
/// A subclass supplies the repository and, where relevant, the columns
/// searched and the showroom-scoping behaviour; everything else is handled.
abstract class ListController<T> extends GetxController {
  ListController({required this.repository, required this.searchColumns});

  final SupabaseRepository<T> repository;

  /// Columns the search box matches against, e.g. `['name', 'phone']`.
  final List<String> searchColumns;

  final Rx<QueryParams> params = QueryParams(
    searchColumns: const <String>[],
  ).obs;

  final Rx<PaginatedResponse<T>> response = PaginatedResponse<T>.empty().obs;

  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  /// Whether the active showroom (from [SessionController]) scopes this list.
  /// A super admin viewing "all showrooms" should override this to false.
  bool get scopeToActiveShowroom => true;

  /// Guards against an older, slower request overwriting a newer one's
  /// result — a real risk when the user types quickly or flips pages before
  /// the previous page has returned.
  int _requestId = 0;

  @override
  void onInit() {
    super.onInit();
    params.value = params.value.copyWith(searchColumns: searchColumns);
    if (scopeToActiveShowroom &&
        Get.isRegistered<SessionController>() &&
        !Get.find<SessionController>().isSuperAdmin) {
      final String? showroomId =
          Get.find<SessionController>().activeShowroomId.value;
      if (showroomId != null) {
        params.value = params.value.copyWith(showroomId: showroomId);
      }
    }
    // `reload()`, not `GetxController.refresh()`. The latter only marks the
    // widget dirty, so calling it here left every list screen showing an empty
    // first page until the user happened to search, sort or change page.
    unawaited(reload());
  }

  /// Re-issues the current query. Named distinctly from
  /// `GetxController.refresh()`, which triggers a widget rebuild rather than
  /// reloading data, and would be shadowed by an override here.
  Future<void> reload() async {
    final int requestId = ++_requestId;
    isLoading.value = true;
    error.value = null;

    try {
      final PaginatedResponse<T> result = await repository.list(params.value);
      if (requestId != _requestId) {
        // A newer request has already started; this result is stale.
        return;
      }
      response.value = result;
    } on Object catch (e, stackTrace) {
      if (requestId != _requestId) {
        return;
      }
      final AppException mapped = ErrorMapper.map(e, stackTrace);
      error.value = mapped;
      AppSnackbar.fromException(mapped);
    } finally {
      if (requestId == _requestId) {
        isLoading.value = false;
      }
    }
  }

  void search(String term) {
    params.value = params.value
        .copyWith(searchTerm: term, clearSearch: term.isEmpty)
        .resetPage();
    reload();
  }

  void sortBy(String column) {
    params.value = params.value.toggleSort(column);
    reload();
  }

  void goToPage(int page) {
    params.value = params.value.copyWith(page: page);
    reload();
  }

  void setPageSize(int size) {
    params.value = params.value.copyWith(pageSize: size).resetPage();
    reload();
  }

  void applyFilter(QueryFilter filter) {
    params.value = params.value.withFilter(filter);
    reload();
  }

  void removeFilter(String column) {
    params.value = params.value.withoutFilter(column);
    reload();
  }

  void setDateRange(DateRange? range, {required String dateColumn}) {
    params.value = params.value
        .copyWith(
          dateRange: range,
          dateColumn: dateColumn,
          clearDateRange: range == null,
        )
        .resetPage();
    reload();
  }

  void clearFilters() {
    params.value = QueryParams(
      searchColumns: searchColumns,
      showroomId: params.value.showroomId,
    );
    reload();
  }

  void toggleIncludeDeleted({required bool value}) {
    params.value = params.value.copyWith(includeDeleted: value).resetPage();
    reload();
  }
}
