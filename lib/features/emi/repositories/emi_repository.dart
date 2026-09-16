import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/emi/models/emi_schedule_model.dart';

/// Remote data source for `emi_schedules`.
///
/// ## Why this one is scoped differently
///
/// `emi_schedules` has **no `showroom_id`**. An instalment belongs to a loan,
/// and the loan belongs to a branch — which is exactly how the RLS policy
/// reads it, through an `exists` against `loans`. So tenancy filtering here
/// goes through the embedded loan (`loans!inner(...)` plus a
/// `loans.showroom_id` filter) rather than through the base class's
/// `showroomId`, which would add an `eq` on a column that does not exist and
/// fail every query.
class EmiRepository extends SupabaseRepository<EmiScheduleModel> {
  EmiRepository({super.client});

  @override
  String get table => DbTables.emiSchedules;

  @override
  String get defaultSortColumn => 'due_date';

  /// No soft-delete column — an instalment is cancelled with its loan.
  @override
  String? get softDeleteColumn => null;

  /// `!inner` matters: without it a filter on `loans.showroom_id` would still
  /// return instalments whose loan did not match, with the embed simply null.
  @override
  String get defaultSelect =>
      '*, loans!inner(id, loan_number, showroom_id, '
      'customers(id, name, phone))';

  @override
  EmiScheduleModel fromJson(Map<String, Object?> json) =>
      EmiScheduleModel.fromJson(json);

  /// The filter that scopes instalments to one branch.
  static QueryFilter showroomFilter(String showroomId) =>
      QueryFilter.equals('loans.showroom_id', showroomId);

  /// Instalments still owing, ordered by how late they are.
  ///
  /// [showroomId] null means every branch the caller can read, which is what
  /// a super admin sees.
  Future<PaginatedResponse<EmiScheduleModel>> listOutstanding({
    String? showroomId,
    DateTime? dueBefore,
    int pageSize = 50,
  }) => list(
    QueryParams(
      pageSize: pageSize,
      filters: <QueryFilter>[
        QueryFilter.inList(
          'status',
          EmiStatus.values
              .where((EmiStatus status) => status.isOutstanding)
              .map((EmiStatus status) => status.value)
              .toList(growable: false),
        ),
        if (showroomId != null) showroomFilter(showroomId),
        if (dueBefore != null)
          QueryFilter.lessOrEqual('due_date', DateUtil.toIsoDate(dueBefore)),
      ],
      sorts: <QuerySort>[
        const QuerySort(column: 'due_date', direction: SortDirection.ascending),
      ],
    ),
  );

  /// One loan's full schedule, in instalment order.
  Future<List<EmiScheduleModel>> listForLoan(String loanId) => listAll(
    QueryParams(
      pageSize: 200,
      filters: <QueryFilter>[QueryFilter.equals('loan_id', loanId)],
      sorts: <QuerySort>[
        const QuerySort(
          column: 'emi_number',
          direction: SortDirection.ascending,
        ),
      ],
    ),
  );
}
