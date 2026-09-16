import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/theme_controller.dart';
import 'package:bike_showroom_management_system/common/layouts/nav_menu_items.dart';
import 'package:bike_showroom_management_system/common/widgets/app_avatar.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/features/auth/controllers/auth_controller.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The permission-aware application chrome (§37): a sidebar, top bar and
/// breadcrumb-style title on desktop; an app bar, drawer and bottom
/// navigation on mobile.
///
/// Every top-level list screen (dashboard, showrooms, users, roles, and every
/// feature added after it) renders `AppShell` where it would otherwise render
/// a bare `Scaffold`. A drill-down screen reached from one of those lists — a
/// form, a detail page — stays a plain `Scaffold` with a back button, which
/// is the correct pattern for a task the user is partway through rather than
/// a place they navigate to directly.
class AppShell extends StatelessWidget {
  const AppShell({
    required this.body,
    this.title,
    this.actions = const <Widget>[],
    this.floatingActionButton,
    super.key,
  });

  final Widget body;
  final String? title;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => AppResponsiveLayout(
    mobile: (BuildContext context) => _MobileShell(
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
      body: body,
    ),
    desktop: (BuildContext context) => _DesktopShell(
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
      body: body,
    ),
  );
}

/// Items visible to the signed-in user, computed once per build rather than
/// per-item, so toggling a role does not re-evaluate permissions n times.
List<NavMenuItem> _visibleItems(List<NavMenuItem> source) {
  if (!Get.isRegistered<SessionController>()) {
    return const <NavMenuItem>[];
  }
  final SessionController session = Get.find<SessionController>();
  return source
      .where((NavMenuItem item) => session.can(item.permission))
      .toList();
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.body,
    this.title,
    this.actions = const <Widget>[],
    this.floatingActionButton,
  });

  final Widget body;
  final String? title;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String current = Get.currentRoute;

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Row(
        children: <Widget>[
          Container(
            width: AppConstants.sidebarWidth,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(right: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.two_wheeler_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          AppConstants.appName,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const _ShowroomSwitcher(),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    children: <Widget>[
                      for (final NavMenuItem item in _visibleItems(
                        NavMenuItems.all,
                      ))
                        _SidebarTile(
                          item: item,
                          isActive: current == item.route,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const _UserFooter(),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      if (title != null)
                        Text(title!, style: theme.textTheme.titleLarge),
                      const Spacer(),
                      ...actions,
                      const _ConnectivityBadge(),
                      IconButton(
                        icon: const Icon(Icons.brightness_6_outlined, size: 20),
                        tooltip: 'Toggle theme',
                        onPressed: () =>
                            Get.find<ThemeController>().toggleThemeMode(),
                      ),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.isActive});

  final NavMenuItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = isActive
        ? theme.colorScheme.primary
        : theme.textTheme.bodyMedium?.color ?? Colors.black;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : null,
        borderRadius: AppRadius.mdAll,
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        leading: Icon(item.icon, size: 20, color: color),
        title: Text(
          item.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: isActive ? null : () => Get.offNamed(item.route),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.body,
    this.title,
    this.actions = const <Widget>[],
    this.floatingActionButton,
  });

  final Widget body;
  final String? title;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final String current = Get.currentRoute;
    final List<NavMenuItem> bottomItems = _visibleItems(NavMenuItems.bottomBar);
    final int selectedIndex = bottomItems.indexWhere(
      (NavMenuItem item) => item.route == current,
    );

    return Scaffold(
      appBar: AppBar(
        title: title == null ? null : Text(title!),
        actions: <Widget>[
          ...actions,
          const _ConnectivityBadge(),
          AppSpacing.hGapSm,
        ],
      ),
      drawer: const _AppDrawer(),
      floatingActionButton: floatingActionButton,
      body: body,
      bottomNavigationBar: bottomItems.length < 2
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (int index) {
                final String route = bottomItems[index].route;
                if (route != current) {
                  Get.offNamed(route);
                }
              },
              destinations: <Widget>[
                for (final NavMenuItem item in bottomItems)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final String current = Get.currentRoute;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const DrawerHeader(child: _UserFooter(expanded: true)),
            const _ShowroomSwitcher(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final NavMenuItem item in _visibleItems(
                    NavMenuItems.all,
                  ))
                    ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      selected: item.route == current,
                      onTap: () {
                        Get.back<void>();
                        if (item.route != current) {
                          Get.offNamed(item.route);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowroomSwitcher extends StatelessWidget {
  const _ShowroomSwitcher();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SessionController>()) {
      return const SizedBox.shrink();
    }
    final SessionController session = Get.find<SessionController>();

    return Obx(() {
      final ShowroomModel? active = session.activeShowroom;
      if (active == null) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: session.canSwitchShowroom
            ? PopupMenuButton<String>(
                tooltip: 'Switch showroom',
                onSelected: session.switchShowroom,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  for (final ShowroomModel showroom in session.showrooms)
                    PopupMenuItem<String>(
                      value: showroom.id,
                      child: Text(showroom.name),
                    ),
                ],
                child: _ShowroomBadge(showroom: active, canSwitch: true),
              )
            : _ShowroomBadge(showroom: active, canSwitch: false),
      );
    });
  }
}

class _ShowroomBadge extends StatelessWidget {
  const _ShowroomBadge({required this.showroom, required this.canSwitch});

  final ShowroomModel showroom;
  final bool canSwitch;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: AppRadius.mdAll,
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.storefront_outlined, size: 16),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(
            showroom.name,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (canSwitch) const Icon(Icons.unfold_more, size: 16),
      ],
    ),
  );
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({this.expanded = false});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SessionController>()) {
      return const SizedBox.shrink();
    }
    final SessionController session = Get.find<SessionController>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Obx(() => AppAvatar(name: session.userName)),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Obx(
                  () => Text(
                    session.userName,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Obx(
                  () => Text(
                    session.user?.roleLabel ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Sign out',
            onPressed: () => Get.find<AuthController>().signOut(),
          ),
        ],
      ),
    );
  }
}

class _ConnectivityBadge extends StatelessWidget {
  const _ConnectivityBadge();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConnectivityService>()) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final ConnectivityService connectivity = Get.find<ConnectivityService>();
      if (connectivity.isOnline) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Tooltip(
          message: 'Working offline. Changes will sync when you reconnect.',
          child: Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AppColors.warning,
          ),
        ),
      );
    });
  }
}
