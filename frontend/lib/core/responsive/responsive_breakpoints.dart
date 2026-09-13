import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Screen width breakpoints for responsive UI layout design.
class ResponsiveBreakpoints {
  static const double mobileMax = 600.0;
  static const double tabletMax = 1024.0;

  /// Returns true if the current screen width is less than [mobileMax] (600px).
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMax;
  }

  /// Returns true if the current screen width is between [mobileMax] and [tabletMax].
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileMax && width < tabletMax;
  }

  /// Returns true if the current screen width is greater than or equal to [tabletMax] (1024px).
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletMax;
  }

  /// Returns true if the application is running on Flutter Web platform.
  static bool get isWeb => kIsWeb;

  /// Returns appropriate column count based on screen width.
  static int getGridColumnCount(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 4}) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Returns appropriate horizontal padding based on screen size.
  static double getHorizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    return 32.0;
  }
}
