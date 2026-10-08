import 'package:flutter/material.dart';

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final Widget? drawer;

  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E222B) : const Color(0xFFE8ECEF);

    return Scaffold(
      extendBody: extendBody,
      extendBodyBehindAppBar: true, // Seamless canvas behind app bar
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: !extendBody, 
        child: body,
      ),
    );
  }
}
