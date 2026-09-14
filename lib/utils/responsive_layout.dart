import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  static bool isTabletOrDesktop(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (kIsWeb) {
      return size.width >= 750;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return size.width >= 750;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      default:
        // On mobile OS, phones in landscape have shortestSide < 600dp (e.g. ~412dp).
        // Only true tablets (sw600dp) should trigger desktop/tablet dual-pane layout.
        return size.width >= 750 && size.shortestSide >= 600;
    }
  }

  static bool isMobile(BuildContext context) => !isTabletOrDesktop(context);

  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return isTabletOrDesktop(context) && size.width < 1100;
  }

  static bool isDesktop(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return isTabletOrDesktop(context) && size.width >= 1100;
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return desktop;
    } else if (isTablet(context)) {
      return tablet ?? desktop;
    } else {
      return mobile;
    }
  }
}

extension ResponsiveContext on BuildContext {
  bool get isMobile => ResponsiveLayout.isMobile(this);
  bool get isTablet => ResponsiveLayout.isTablet(this);
  bool get isDesktop => ResponsiveLayout.isDesktop(this);
  bool get isTabletOrDesktop => ResponsiveLayout.isTabletOrDesktop(this);
}
