import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// A widget that renders different layouts based on screen constraints.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.tabletMax) {
          return desktop;
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.mobileMax) {
          return tablet ?? desktop;
        } else {
          return mobile;
        }
      },
    );
  }
}
