import 'package:flutter/material.dart';
import '../../core/responsive/responsive_breakpoints.dart';

/// Utility to present adaptive dialogs and modal sheets across Web and Mobile devices.
class AdaptiveDialog {
  /// Shows a responsive dialog. On Web/Desktop, limits width to desktop max.
  /// On Mobile, presents a full-width bottom sheet or compact dialog.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
    double desktopWidth = 640.0,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (isMobile) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppBar(
                  title: Text(title),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: child,
                  ),
                ),
                if (actions != null && actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return showDialog<T>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: desktopWidth,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12.0),
                Flexible(
                  child: SingleChildScrollView(
                    child: child,
                  ),
                ),
                if (actions != null && actions.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
