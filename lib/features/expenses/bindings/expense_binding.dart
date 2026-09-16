import 'package:bike_showroom_management_system/features/expenses/controllers/expense_controller.dart';
import 'package:bike_showroom_management_system/features/expenses/repositories/expense_category_repository.dart';
import 'package:bike_showroom_management_system/features/expenses/repositories/expense_repository.dart';
import 'package:get/get.dart';

class ExpenseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExpenseRepository>(ExpenseRepository.new);
    Get.lazyPut<ExpenseController>(
      () => ExpenseController(repository: Get.find<ExpenseRepository>()),
    );
  }
}

class ExpenseFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExpenseRepository>(ExpenseRepository.new);
    Get.lazyPut<ExpenseCategoryRepository>(ExpenseCategoryRepository.new);
    Get.lazyPut<ExpenseFormController>(
      () => ExpenseFormController(
        expenseRepository: Get.find<ExpenseRepository>(),
        categoryRepository: Get.find<ExpenseCategoryRepository>(),
      ),
    );
  }
}

class ExpenseCategoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExpenseCategoryRepository>(ExpenseCategoryRepository.new);
    Get.lazyPut<ExpenseCategoryController>(
      () => ExpenseCategoryController(
        repository: Get.find<ExpenseCategoryRepository>(),
      ),
    );
  }
}
