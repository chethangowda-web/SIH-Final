import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Navigation item data structure for adaptive navigation shell.
class AdaptiveNavigationItem {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget body;

  const AdaptiveNavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.body,
  });
}

/// An adaptive page scaffold that automatically switches between NavigationRail
/// on Web/Desktop and BottomNavigationBar on Mobile devices.
class AdaptiveScaffold extends StatefulWidget {
  final String title;
  final List<AdaptiveNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
    this.actions,
    this.floatingActionButton,
  });

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: widget.actions,
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onSelectedIndexChanged,
              labelType: NavigationRailLabelType.all,
              destinations: widget.items.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon ?? item.icon),
                  label: Text(item.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: widget.items[widget.selectedIndex].body,
            ),
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.actions,
      ),
      body: widget.items[widget.selectedIndex].body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onSelectedIndexChanged,
        destinations: widget.items.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon ?? item.icon),
            label: item.label,
          );
        }).toList(),
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
