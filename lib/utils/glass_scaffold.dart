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

    return Scaffold(
      extendBody: extendBody,
      extendBodyBehindAppBar: true, // Fix for White Bar at top
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: Colors.transparent, // Important for background to show
      body: Stack(
        children: [
          // 1. Global Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [
                      const Color(0xFF0B0F19), // Slate 950
                      const Color(0xFF0F172A), // Slate 900
                      const Color(0xFF131C31), // Deep Slate Blue
                    ]
                  : [
                      const Color(0xFFF8FAFC), // Slate 50
                      const Color(0xFFF1F5F9), // Slate 100
                      const Color(0xFFE2E8F0), // Slate 200
                    ],
              ),
            ),
          ),
          
          // 2. Mesh / Noise Overlay (Optional for texture)
          // Opacity low to keep it subtle
          
          // 3. Content
          SafeArea(
            bottom: !extendBody, 
            child: body,
          ),
        ],
      ),
    );
  }
}
