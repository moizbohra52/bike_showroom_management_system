import 'dart:async';

import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:flutter/material.dart';

/// A debounced search box.
///
/// The debounce lives here rather than in every controller, so a list screen
/// cannot forget it and fire a query per keystroke. [onChanged] fires
/// [AppConstants.searchDebounce] after typing stops, and immediately on a
/// programmatic clear so the list resets without waiting.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    this.hint = 'Search...',
    this.initialValue,
    required this.onChanged,
    this.autofocus = false,
    super.key,
  });

  final String hint;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.searchDebounce, () {
      widget.onChanged(value);
    });
    // Keeps the clear icon in sync immediately, without waiting on the timer.
    setState(() {});
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    autofocus: widget.autofocus,
    onChanged: _handleChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search, size: 18),
      suffixIcon: _controller.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: _clear,
              visualDensity: VisualDensity.compact,
              tooltip: 'Clear search',
            ),
    ),
  );
}
