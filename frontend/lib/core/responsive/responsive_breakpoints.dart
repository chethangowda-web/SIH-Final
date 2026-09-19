import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Screen width breakpoints and adaptive sizing helpers for responsive UI layout design.
class ResponsiveBreakpoints {
  static const double smallMobileMax = 380.0;
  static const double mobileMax = 600.0;
  static const double tabletMax = 1024.0;
  static const double defaultDesktopMaxWidth = 1180.0;
  static const double defaultDesktopMaxHeight = 840.0;

  /// Returns true if the screen width is less than [smallMobileMax] (380px).
  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < smallMobileMax;
  }

  /// Returns true if the screen width is less than [mobileMax] (600px).
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMax;
  }

  /// Returns true if the screen width is between [mobileMax] and [tabletMax] (600px to 1024px).
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileMax && width < tabletMax;
  }

  /// Returns true if the screen width is greater than or equal to [tabletMax] (1024px).
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletMax;
  }

  /// Returns true if the user is likely on a touch-first device (mobile or tablet).
  static bool isTouch(BuildContext context) {
    return isMobile(context) || isTablet(context);
  }

  /// Returns true if the application is running on Flutter Web platform.
  static bool get isWeb => kIsWeb;

  /// Returns appropriate column count based on screen width.
  static int getGridColumnCount(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Returns appropriate horizontal padding based on screen size.
  static double getHorizontalPadding(BuildContext context) {
    if (isSmallMobile(context)) return 12.0;
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    return 32.0;
  }

  /// Dynamically computes adaptive dialog width based on screen width.
  static double getDialogWidth(
    BuildContext context, {
    double? maxDesktopWidth,
  }) {
    final screenW = MediaQuery.of(context).size.width;
    final effectiveMax = maxDesktopWidth ?? defaultDesktopMaxWidth;
    if (screenW < 600.0) {
      return (screenW * 0.96).clamp(320.0, screenW);
    } else if (screenW < 1024.0) {
      return (screenW * 0.92).clamp(560.0, effectiveMax);
    }
    return effectiveMax.clamp(600.0, screenW * 0.90);
  }

  /// Dynamically computes adaptive dialog height based on screen height.
  static double getDialogHeight(
    BuildContext context, {
    double? maxDesktopHeight,
  }) {
    final screenH = MediaQuery.of(context).size.height;
    final effectiveMax = maxDesktopHeight ?? defaultDesktopMaxHeight;
    if (screenH < 700.0) {
      return (screenH - 24.0).clamp(280.0, screenH);
    } else if (screenH < 900.0) {
      return (screenH * 0.92).clamp(400.0, effectiveMax);
    }
    return effectiveMax.clamp(400.0, screenH * 0.90);
  }
}
