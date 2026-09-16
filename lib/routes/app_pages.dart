import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/features/auth/bindings/auth_binding.dart';
import 'package:bike_showroom_management_system/features/auth/views/account_blocked_view.dart';
import 'package:bike_showroom_management_system/features/auth/views/forgot_password_view.dart';
import 'package:bike_showroom_management_system/features/auth/views/login_view.dart';
import 'package:bike_showroom_management_system/features/auth/views/reset_password_view.dart';
import 'package:bike_showroom_management_system/features/auth/views/splash_view.dart';
import 'package:bike_showroom_management_system/features/billing/bindings/invoice_binding.dart';
import 'package:bike_showroom_management_system/features/billing/views/invoice_details_view.dart';
import 'package:bike_showroom_management_system/features/billing/views/invoice_list_view.dart';
import 'package:bike_showroom_management_system/features/customers/bindings/customer_binding.dart';
import 'package:bike_showroom_management_system/features/customers/views/customer_form_view.dart';
import 'package:bike_showroom_management_system/features/customers/views/customer_list_view.dart';
import 'package:bike_showroom_management_system/features/dashboard/views/dashboard_view.dart';
import 'package:bike_showroom_management_system/features/emi/bindings/emi_binding.dart';
import 'package:bike_showroom_management_system/features/emi/views/emi_dashboard_view.dart';
import 'package:bike_showroom_management_system/features/finance/bindings/finance_binding.dart';
import 'package:bike_showroom_management_system/features/finance/views/finance_company_list_view.dart';
import 'package:bike_showroom_management_system/features/finance/views/loan_details_view.dart';
import 'package:bike_showroom_management_system/features/finance/views/loan_list_view.dart';
import 'package:bike_showroom_management_system/features/inventory/bindings/inventory_binding.dart';
import 'package:bike_showroom_management_system/features/inventory/views/inventory_form_view.dart';
import 'package:bike_showroom_management_system/features/inventory/views/inventory_list_view.dart';
import 'package:bike_showroom_management_system/features/inventory/views/stock_history_view.dart';
import 'package:bike_showroom_management_system/features/payments/bindings/payment_binding.dart';
import 'package:bike_showroom_management_system/features/payments/views/payment_form_view.dart';
import 'package:bike_showroom_management_system/features/payments/views/payment_list_view.dart';
import 'package:bike_showroom_management_system/features/products/bindings/product_binding.dart';
import 'package:bike_showroom_management_system/features/products/views/brand_list_view.dart';
import 'package:bike_showroom_management_system/features/products/views/product_form_view.dart';
import 'package:bike_showroom_management_system/features/products/views/product_list_view.dart';
import 'package:bike_showroom_management_system/features/roles/bindings/role_binding.dart';
import 'package:bike_showroom_management_system/features/roles/views/role_form_view.dart';
import 'package:bike_showroom_management_system/features/roles/views/role_list_view.dart';
import 'package:bike_showroom_management_system/features/roles/views/role_permissions_view.dart';
import 'package:bike_showroom_management_system/features/sales/bindings/sale_binding.dart';
import 'package:bike_showroom_management_system/features/sales/views/sale_create_view.dart';
import 'package:bike_showroom_management_system/features/sales/views/sale_details_view.dart';
import 'package:bike_showroom_management_system/features/sales/views/sale_list_view.dart';
import 'package:bike_showroom_management_system/features/showroom/bindings/showroom_binding.dart';
import 'package:bike_showroom_management_system/features/showroom/views/showroom_form_view.dart';
import 'package:bike_showroom_management_system/features/showroom/views/showroom_list_view.dart';
import 'package:bike_showroom_management_system/features/users/bindings/user_binding.dart';
import 'package:bike_showroom_management_system/features/users/views/user_assignment_view.dart';
import 'package:bike_showroom_management_system/features/users/views/user_form_view.dart';
import 'package:bike_showroom_management_system/features/users/views/user_invite_view.dart';
import 'package:bike_showroom_management_system/features/users/views/user_list_view.dart';
import 'package:bike_showroom_management_system/features/vehicles/bindings/vehicle_binding.dart';
import 'package:bike_showroom_management_system/features/vehicles/views/vehicle_form_view.dart';
import 'package:bike_showroom_management_system/features/vehicles/views/vehicle_list_view.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:bike_showroom_management_system/routes/middleware/auth_middleware.dart';
import 'package:bike_showroom_management_system/routes/middleware/permission_middleware.dart';
import 'package:bike_showroom_management_system/routes/views/not_found_view.dart';
import 'package:get/get.dart';

/// The route table.
///
/// Every protected entry carries [AuthMiddleware] and [PermissionMiddleware],
/// so authentication and authorisation are enforced by the router rather than
/// by each screen remembering to check. That also covers a deep link and, on
/// web, a URL typed straight into the address bar.
class AppPages {
  const AppPages._();

  static const String initial = AppRoutes.splash;

  /// Applied to every authenticated route.
  static List<GetMiddleware> get _protected => <GetMiddleware>[
    AuthMiddleware(),
    PermissionMiddleware(),
  ];

  /// For a create/edit form, which a role may reach through either right.
  ///
  /// `AppRoutes.routePermissions` can only name one permission per route, and
  /// naming `<module>.create` there locks out a role that may edit but not
  /// create — SERVICE MANAGER holds `customers.edit` without
  /// `customers.create`, so tapping Edit would bounce them to the dashboard.
  static List<GetMiddleware> _protectedAnyOf(List<String> permissions) =>
      <GetMiddleware>[
        AuthMiddleware(),
        PermissionMiddleware(anyOfPermissions: permissions),
      ];

  static final List<GetPage<dynamic>> routes = <GetPage<dynamic>>[
    // ------------------------------------------------------------- auth
    GetPage<void>(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
      middlewares: <GetMiddleware>[GuestOnlyMiddleware()],
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordView(),
      binding: AuthBinding(),
      middlewares: <GetMiddleware>[GuestOnlyMiddleware()],
    ),
    GetPage<void>(
      name: AppRoutes.resetPassword,
      page: () => const ResetPasswordView(),
      binding: AuthBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.accountBlocked,
      page: () => const AccountBlockedView(),
      binding: AuthBinding(),
      // Deliberately guarded by AuthMiddleware only: this screen exists
      // precisely for a user who holds no permissions, so a permission check
      // here would redirect them in a loop.
      middlewares: <GetMiddleware>[AuthMiddleware()],
    ),

    // -------------------------------------------------------- dashboard
    GetPage<void>(
      name: AppRoutes.dashboard,
      page: () => const DashboardView(),
      middlewares: _protected,
      transition: Transition.fadeIn,
    ),

    // --------------------------------------------------------- showroom
    GetPage<void>(
      name: AppRoutes.showrooms,
      page: () => const ShowroomListView(),
      binding: ShowroomBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.showroomForm,
      page: () => const ShowroomFormView(),
      binding: ShowroomFormBinding(),
      middlewares: _protected,
    ),

    // ------------------------------------------------------------ users
    GetPage<void>(
      name: AppRoutes.users,
      page: () => const UserListView(),
      binding: UserBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.userInvite,
      page: () => const UserInviteView(),
      binding: UserInviteBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.userForm,
      page: () => const UserFormView(),
      binding: UserFormBinding(),
      middlewares: _protected,
    ),
    // Reuses the edit form: an internal admin tool has little use for a
    // separate read-only profile page, and every field on it is already
    // presented plainly rather than as an editable control's raw value.
    GetPage<void>(
      name: AppRoutes.userDetails,
      page: () => const UserFormView(),
      binding: UserFormBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.userRoles,
      page: () => const UserAssignmentView(),
      binding: UserAssignmentBinding(),
      middlewares: _protected,
    ),

    // ------------------------------------------------------------ roles
    GetPage<void>(
      name: AppRoutes.roles,
      page: () => const RoleListView(),
      binding: RoleBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.roleForm,
      page: () => const RoleFormView(),
      binding: RoleFormBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.rolePermissions,
      page: () => const RolePermissionsView(),
      binding: RolePermissionsBinding(),
      middlewares: _protected,
    ),

    // --------------------------------------------------------- products
    GetPage<void>(
      name: AppRoutes.products,
      page: () => const ProductListView(),
      binding: ProductBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.productForm,
      page: () => const ProductFormView(),
      binding: ProductFormBinding(),
      middlewares: _protectedAnyOf(<String>[
        AppPermissions.productsCreate,
        AppPermissions.productsEdit,
      ]),
    ),
    GetPage<void>(
      name: AppRoutes.brands,
      page: () => const BrandListView(),
      binding: BrandBinding(),
      middlewares: _protected,
    ),

    // -------------------------------------------------------- inventory
    GetPage<void>(
      name: AppRoutes.inventory,
      page: () => const InventoryListView(),
      binding: InventoryBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.inventoryForm,
      page: () => const InventoryFormView(),
      binding: InventoryFormBinding(),
      middlewares: _protectedAnyOf(<String>[
        AppPermissions.inventoryCreate,
        AppPermissions.inventoryEdit,
      ]),
    ),
    GetPage<void>(
      name: AppRoutes.stockHistory,
      page: () => const StockHistoryView(),
      binding: StockHistoryBinding(),
      middlewares: _protected,
    ),

    // -------------------------------------------------------- customers
    GetPage<void>(
      name: AppRoutes.customers,
      page: () => const CustomerListView(),
      binding: CustomerBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.customerForm,
      page: () => const CustomerFormView(),
      binding: CustomerFormBinding(),
      middlewares: _protectedAnyOf(<String>[
        AppPermissions.customersCreate,
        AppPermissions.customersEdit,
      ]),
    ),

    // --------------------------------------------------------- vehicles
    // One screen serves both the branch-wide list and a single customer's
    // garage; which one is decided by the argument, not by the route.
    GetPage<void>(
      name: AppRoutes.customerVehicles,
      page: () => const VehicleListView(),
      binding: VehicleBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.vehicleForm,
      page: () => const VehicleFormView(),
      binding: VehicleFormBinding(),
      middlewares: _protectedAnyOf(<String>[
        AppPermissions.vehiclesCreate,
        AppPermissions.vehiclesEdit,
      ]),
    ),

    // ------------------------------------------------------------ sales
    GetPage<void>(
      name: AppRoutes.sales,
      page: () => const SaleListView(),
      binding: SaleBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.saleCreate,
      page: () => const SaleCreateView(),
      binding: SaleCreateBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.saleDetails,
      page: () => const SaleDetailsView(),
      binding: SaleDetailsBinding(),
      middlewares: _protected,
    ),

    // ---------------------------------------------------------- billing
    GetPage<void>(
      name: AppRoutes.invoices,
      page: () => const InvoiceListView(),
      binding: InvoiceBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.invoiceDetails,
      page: () => const InvoiceDetailsView(),
      binding: InvoiceDetailsBinding(),
      middlewares: _protected,
    ),

    // --------------------------------------------------------- payments
    GetPage<void>(
      name: AppRoutes.payments,
      page: () => const PaymentListView(),
      binding: PaymentBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.paymentForm,
      page: () => const PaymentFormView(),
      binding: PaymentFormBinding(),
      middlewares: _protected,
    ),

    // ---------------------------------------------------------- finance
    GetPage<void>(
      name: AppRoutes.financeCompanies,
      page: () => const FinanceCompanyListView(),
      binding: FinanceCompanyBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.loans,
      page: () => const LoanListView(),
      binding: LoanBinding(),
      middlewares: _protected,
    ),
    GetPage<void>(
      name: AppRoutes.loanDetails,
      page: () => const LoanDetailsView(),
      binding: LoanDetailsBinding(),
      middlewares: _protected,
    ),

    // -------------------------------------------------------------- emi
    GetPage<void>(
      name: AppRoutes.emiDashboard,
      page: () => const EmiDashboardView(),
      binding: EmiBinding(),
      middlewares: _protected,
    ),

    // ------------------------------------------------------------ misc
    GetPage<void>(name: AppRoutes.notFound, page: () => const NotFoundView()),
  ];

  /// Serves an explicit screen for an unknown path.
  ///
  /// Required on web, where a user can type or bookmark anything; without it
  /// GetX shows a bare error page.
  static final GetPage<void> unknownRoute = GetPage<void>(
    name: AppRoutes.notFound,
    page: () => const NotFoundView(),
  );
}
