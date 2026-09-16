import 'package:bike_showroom_management_system/features/accounting/controllers/accounting_controller.dart';
import 'package:bike_showroom_management_system/features/accounting/repositories/account_repository.dart';
import 'package:bike_showroom_management_system/features/accounting/repositories/journal_repository.dart';
import 'package:get/get.dart';

/// Serves both the chart of accounts and the trial balance — the two are the
/// same data read two ways, so one controller loads both.
class AccountingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountRepository>(AccountRepository.new);
    Get.lazyPut<AccountingController>(
      () => AccountingController(
        accountRepository: Get.find<AccountRepository>(),
      ),
    );
  }
}

class JournalBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<JournalRepository>(JournalRepository.new);
    Get.lazyPut<JournalController>(
      () => JournalController(repository: Get.find<JournalRepository>()),
    );
  }
}
