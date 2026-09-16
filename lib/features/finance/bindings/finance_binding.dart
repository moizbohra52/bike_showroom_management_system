import 'package:bike_showroom_management_system/features/emi/repositories/emi_repository.dart';
import 'package:bike_showroom_management_system/features/finance/controllers/finance_controller.dart';
import 'package:bike_showroom_management_system/features/finance/models/loan_model.dart';
import 'package:bike_showroom_management_system/features/finance/repositories/finance_company_repository.dart';
import 'package:bike_showroom_management_system/features/finance/repositories/loan_repository.dart';
import 'package:get/get.dart';

class FinanceCompanyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FinanceCompanyRepository>(FinanceCompanyRepository.new);
    Get.lazyPut<FinanceCompanyController>(
      () => FinanceCompanyController(
        repository: Get.find<FinanceCompanyRepository>(),
      ),
    );
  }
}

class LoanBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoanRepository>(LoanRepository.new);
    Get.lazyPut<LoanController>(
      () => LoanController(repository: Get.find<LoanRepository>()),
    );
  }
}

/// The details screen reads the schedule from `emi_schedules`, not from
/// `loans`, so it needs the EMI repository rather than the loan one.
class LoanDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmiRepository>(EmiRepository.new);
    Get.lazyPut<LoanDetailsController>(
      () => LoanDetailsController(
        emiRepository: Get.find<EmiRepository>(),
        loan: Get.arguments as LoanModel,
      ),
    );
  }
}
