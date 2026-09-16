import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';

/// A row from `permissions`.
class PermissionModel {
  const PermissionModel({
    required this.id,
    required this.module,
    required this.action,
    this.description,
  });

  factory PermissionModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return PermissionModel(
      id: reader.requireString('id'),
      module: reader.string('module'),
      action: reader.string('action'),
      description: reader.stringOrNull('description'),
    );
  }

  final String id;
  final String module;
  final String action;
  final String? description;

  /// The `module.action` key used everywhere in the client.
  String get key => '$module.$action';

  /// Label for the permission matrix in the role editor.
  String get label =>
      description ?? '${_titleCase(action)} ${_titleCase(module)}';

  static String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'module': module,
    'action': action,
    'description': description,
  };

  @override
  bool operator ==(Object other) => other is PermissionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Permission($key)';
}

/// An immutable, fast-lookup set of permission keys.
///
/// ## Why a dedicated type
///
/// Permission checks happen on almost every rebuild — every navigation item,
/// every action button, every table row menu. A `List<String>.contains` is
/// O(n) over ~120 entries and would run thousands of times per frame on a
/// desktop table. Backing this with a `Set` makes each check O(1).
///
/// ## What this is not
///
/// This is a *projection* of server-side authority, cached for rendering. It
/// is never the thing that grants access: every read and write is independently
/// authorised by Row Level Security calling `has_permission(module, action)`.
/// A user who tampered with this set would see extra buttons that all fail.
class PermissionSet {
  PermissionSet(Iterable<String> keys)
    : _keys = Set<String>.unmodifiable(keys),
      isSuperAdmin = false;

  /// A super admin implicitly holds every permission, present and future.
  /// Modelled as a flag rather than by expanding the catalogue so that adding
  /// a permission does not require re-seeding existing super admins.
  PermissionSet.superAdmin() : _keys = const <String>{}, isSuperAdmin = true;

  const PermissionSet.empty() : _keys = const <String>{}, isSuperAdmin = false;

  final Set<String> _keys;

  final bool isSuperAdmin;

  Set<String> get keys =>
      isSuperAdmin ? Set<String>.unmodifiable(AppPermissions.all) : _keys;

  int get length => isSuperAdmin ? AppPermissions.all.length : _keys.length;

  bool get isEmpty => !isSuperAdmin && _keys.isEmpty;

  /// Whether the holder has [permission], expressed as `module.action`.
  bool has(String permission) => isSuperAdmin || _keys.contains(permission);

  bool hasModuleAction(String module, String action) => has('$module.$action');

  /// True when *any* of [permissions] is held. Used for a navigation group
  /// that should appear if the user can reach any screen inside it.
  bool hasAny(Iterable<String> permissions) {
    if (isSuperAdmin) {
      return true;
    }
    for (final String permission in permissions) {
      if (_keys.contains(permission)) {
        return true;
      }
    }
    return false;
  }

  /// True only when every one of [permissions] is held.
  bool hasAll(Iterable<String> permissions) {
    if (isSuperAdmin) {
      return true;
    }
    for (final String permission in permissions) {
      if (!_keys.contains(permission)) {
        return false;
      }
    }
    return true;
  }

  /// Whether the holder can see any part of [module]. Drives whether a
  /// sidebar entry is rendered at all.
  bool canAccessModule(String module) {
    if (isSuperAdmin) {
      return true;
    }
    final String prefix = '$module.';
    for (final String key in _keys) {
      if (key.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  /// Actions held within [module], for building a row action menu.
  Set<String> actionsFor(String module) {
    if (isSuperAdmin) {
      return AppPermissions.all
          .where((String key) => key.startsWith('$module.'))
          .map((String key) => key.split('.').last)
          .toSet();
    }
    final String prefix = '$module.';
    return _keys
        .where((String key) => key.startsWith(prefix))
        .map((String key) => key.substring(prefix.length))
        .toSet();
  }

  PermissionSet merge(PermissionSet other) {
    if (isSuperAdmin || other.isSuperAdmin) {
      return PermissionSet.superAdmin();
    }
    return PermissionSet(<String>{..._keys, ...other._keys});
  }

  List<String> toJson() => keys.toList()..sort();

  @override
  String toString() => isSuperAdmin
      ? 'PermissionSet(SUPER ADMIN: all)'
      : 'PermissionSet(${_keys.length} permissions)';
}
