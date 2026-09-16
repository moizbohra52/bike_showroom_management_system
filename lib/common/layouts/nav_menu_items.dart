import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';

/// One entry in the navigation menu.
class NavMenuItem {
  const NavMenuItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.permission,
  });

  final String label;
  final IconData icon;
  final String route;

  /// Gating permission. The item is hidden entirely (not merely disabled)
  /// when the signed-in user lacks it — an unreachable menu entry is clutter,
  /// and [PermissionMiddleware] would bounce them straight back regardless.
  final String permission;
}

/// The complete navigation menu, in display order.
///
/// A single source of truth read by both the desktop sidebar and the mobile
/// drawer, so the two can never drift into showing different items. New
/// entries are added here as each feature ships a list screen — listing a
/// route before it exists in [AppPages.routes] would produce a dead link, so
/// this only ever names routes that are actually registered.
class NavMenuItems {
  const NavMenuItems._();

  static const List<NavMenuItem> all = <NavMenuItem>[
    NavMenuItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: AppRoutes.dashboard,
      permission: AppPermissions.dashboardView,
    ),
    NavMenuItem(
      label: 'Showrooms',
      icon: Icons.storefront_outlined,
      route: AppRoutes.showrooms,
      permission: AppPermissions.showroomView,
    ),
    NavMenuItem(
      label: 'Products',
      icon: Icons.two_wheeler_outlined,
      route: AppRoutes.products,
      permission: AppPermissions.productsView,
    ),
    NavMenuItem(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      route: AppRoutes.inventory,
      permission: AppPermissions.inventoryView,
    ),
    NavMenuItem(
      label: 'Customers',
      icon: Icons.people_outline,
      route: AppRoutes.customers,
      permission: AppPermissions.customersView,
    ),
    NavMenuItem(
      label: 'Vehicles',
      icon: Icons.directions_bike_outlined,
      route: AppRoutes.customerVehicles,
      permission: AppPermissions.vehiclesView,
    ),
    NavMenuItem(
      label: 'Sales',
      icon: Icons.receipt_long_outlined,
      route: AppRoutes.sales,
      permission: AppPermissions.salesView,
    ),
    NavMenuItem(
      label: 'Billing',
      icon: Icons.description_outlined,
      route: AppRoutes.invoices,
      permission: AppPermissions.billingView,
    ),
    NavMenuItem(
      label: 'Payments',
      icon: Icons.payments_outlined,
      route: AppRoutes.payments,
      permission: AppPermissions.paymentsView,
    ),
    NavMenuItem(
      label: 'Loans',
      icon: Icons.account_balance_wallet_outlined,
      route: AppRoutes.loans,
      permission: AppPermissions.financeView,
    ),
    NavMenuItem(
      label: 'EMI Collections',
      icon: Icons.event_repeat_outlined,
      route: AppRoutes.emiDashboard,
      permission: AppPermissions.emiView,
    ),
    NavMenuItem(
      label: 'Purchases',
      icon: Icons.shopping_cart_outlined,
      route: AppRoutes.purchases,
      permission: AppPermissions.purchasesView,
    ),
    NavMenuItem(
      label: 'Expenses',
      icon: Icons.receipt_outlined,
      route: AppRoutes.expenses,
      permission: AppPermissions.expensesView,
    ),
    NavMenuItem(
      label: 'Accounting',
      icon: Icons.account_balance_outlined,
      route: AppRoutes.accounting,
      permission: AppPermissions.accountingView,
    ),
    NavMenuItem(
      label: 'Users',
      icon: Icons.manage_accounts_outlined,
      route: AppRoutes.users,
      permission: AppPermissions.usersView,
    ),
    NavMenuItem(
      label: 'Roles & Permissions',
      icon: Icons.admin_panel_settings_outlined,
      route: AppRoutes.roles,
      permission: AppPermissions.rolesView,
    ),
  ];

  /// Items on the compact bottom navigation bar. A phone has room for four or
  /// five destinations at most; everything else lives in the drawer.
  ///
  /// These are the destinations a showroom's floor staff use all day, which is
  /// not the same as the first few entries of [all] — administration lives in
  /// the drawer, where it is reached occasionally rather than constantly.
  static const List<NavMenuItem> bottomBar = <NavMenuItem>[
    NavMenuItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: AppRoutes.dashboard,
      permission: AppPermissions.dashboardView,
    ),
    NavMenuItem(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      route: AppRoutes.inventory,
      permission: AppPermissions.inventoryView,
    ),
    NavMenuItem(
      label: 'Sales',
      icon: Icons.receipt_long_outlined,
      route: AppRoutes.sales,
      permission: AppPermissions.salesView,
    ),
    NavMenuItem(
      label: 'Customers',
      icon: Icons.people_outline,
      route: AppRoutes.customers,
      permission: AppPermissions.customersView,
    ),
  ];
}
