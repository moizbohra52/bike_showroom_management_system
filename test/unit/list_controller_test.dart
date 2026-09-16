import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository that answers from memory, so the controller can be exercised
/// without a Supabase client.
class _FakeRepository extends SupabaseRepository<String> {
  static const List<String> rows = <String>['a', 'b', 'c'];

  int listCallCount = 0;
  QueryParams? lastParams;

  @override
  String get table => 'fake';

  @override
  String fromJson(Map<String, Object?> json) => json['value']! as String;

  @override
  Future<PaginatedResponse<String>> list(
    QueryParams params, {
    String? select,
  }) async {
    listCallCount++;
    lastParams = params;
    return PaginatedResponse<String>(
      items: rows,
      totalCount: rows.length,
      page: params.page,
      pageSize: params.pageSize,
    );
  }
}

class _FakeListController extends ListController<String> {
  _FakeListController(_FakeRepository repository)
    : super(repository: repository, searchColumns: const <String>['name']);

  // No SessionController is registered in a unit test; disabling showroom
  // scoping keeps that explicit rather than relying on the lookup failing.
  @override
  bool get scopeToActiveShowroom => false;
}

void main() {
  group('ListController', () {
    test('loads its first page on init', () async {
      // Regression: onInit used to call `GetxController.refresh()`, which only
      // marks the widget dirty. Every list screen therefore opened empty and
      // stayed empty until the user happened to search, sort or page.
      final _FakeRepository repository = _FakeRepository();
      final _FakeListController controller = _FakeListController(repository)
        ..onInit();

      // onInit fires the load without awaiting it, so yield to the microtask
      // queue before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(repository.listCallCount, 1);
      expect(controller.response.value.items, <String>['a', 'b', 'c']);
      expect(controller.isLoading.value, isFalse);
    });

    test('carries the declared search columns into the query', () async {
      final _FakeRepository repository = _FakeRepository();
      _FakeListController(repository).onInit();
      await Future<void>.delayed(Duration.zero);

      expect(repository.lastParams!.searchColumns, <String>['name']);
    });

    test('search resets to the first page', () async {
      final _FakeRepository repository = _FakeRepository();
      final _FakeListController controller = _FakeListController(repository)
        ..onInit();
      await Future<void>.delayed(Duration.zero);

      controller.goToPage(3);
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastParams!.page, 3);

      // Staying on page 3 after a new search would show an empty page for a
      // result set that has only one.
      controller.search('shine');
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastParams!.page, 1);
      expect(repository.lastParams!.searchTerm, 'shine');
    });

    test('a filter applied before init survives the first load', () async {
      // The stock-history and customer-garage screens both seed a filter in
      // their own onInit before calling super, so this ordering has to hold.
      final _FakeRepository repository = _FakeRepository();
      final _FakeListController controller = _FakeListController(repository);
      controller.params.value = controller.params.value.withFilter(
        const QueryFilter.equals('inventory_id', 'unit-1'),
      );
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(repository.lastParams!.filters, hasLength(1));
      expect(repository.lastParams!.filters.first.column, 'inventory_id');
    });

    test('clearFilters keeps the showroom scope', () async {
      final _FakeRepository repository = _FakeRepository();
      final _FakeListController controller = _FakeListController(repository)
        ..onInit();
      await Future<void>.delayed(Duration.zero);

      controller.params.value = controller.params.value.copyWith(
        showroomId: 'showroom-1',
      );
      controller.clearFilters();
      await Future<void>.delayed(Duration.zero);

      // Dropping the tenancy scope along with the user's filters would widen
      // the query to every branch the caller can read.
      expect(repository.lastParams!.showroomId, 'showroom-1');
    });
  });
}
