import 'package:flutter/material.dart';
import 'package:sme_buddy/features/subscription/upgrade_dialog.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassScaffold(
      appBar: AppBar(title: Text("Plans & Features", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), backgroundColor: Colors.transparent, iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black)),
      body: SingleChildScrollView(
         padding: const EdgeInsets.all(16),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
              Text(
                "Choose the plan that fits your business.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 24),
              
              _buildPlanCard(
                context,
                title: "PLUS (Starter)",
                color: Colors.blue,
                features: [
                  "Single User (Owner Only)",
                  "Max 500 Inventory Items",
                  "Basic Reporting",
                  "Basic Reporting",
                  "x No Customer Credit Book",
                  "x No Team Management",
                ],
                isPopular: false,
                isDark: isDark,
              ),
              
              const SizedBox(height: 16),
              
              _buildPlanCard(
                context,
                title: "PRO (Unlimited)",
                color: Colors.purple,
                features: [
                  "Unlimited Users (Staff Logins)",
                  "Unlimited Inventory",
                  "Advanced Analytics",
                  "Customer Credit Book (Naya Potha)",
                  "Priority Support",
                  "All Future Updates"
                ],
                isPopular: true,
                isDark: isDark,
              ),
              
              const SizedBox(height: 32),
              
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 12,
                border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.manage_accounts, color: isDark ? Colors.white54 : Colors.black54),
                        const SizedBox(width: 8),
                        Text("Account Management", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Subscriptions are managed externally via the Synthora Portal.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "synthora.lk",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: isDark ? Colors.cyanAccent : Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "( Subscription Management Portal )",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              )
           ],
         ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, {required String title, required Color color, required List<String> features, required bool isPopular, required bool isDark}) {
    return GlassCard(
      borderRadius: 20,
      border: Border.all(color: isPopular ? color : (isDark ? Colors.white24 : Colors.black12), width: isPopular ? 2 : 1),
      child: Column(
        children: [
           if (isPopular)
             Container(
               width: double.infinity,
               padding: const EdgeInsets.symmetric(vertical: 4),
               decoration: BoxDecoration(
                 color: color, 
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(18)) // Match card radius - 2
               ), 
               child: const Text("RECOMMENDED", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
             ),
           
           Padding(
             padding: const EdgeInsets.all(24),
             child: Column(
               children: [
                 Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                 const SizedBox(height: 24),
                   ...features.map((f) {
                     bool isNegative = f.startsWith("x ");
                     String text = isNegative ? f.substring(2) : f;
                     return Padding(
                       padding: const EdgeInsets.symmetric(vertical: 4),
                       child: Row(
                         children: [
                           Icon(
                             isNegative ? Icons.cancel : Icons.check_circle, 
                             color: isNegative ? (isDark ? Colors.white38 : Colors.grey) : color, 
                             size: 20
                           ),
                           const SizedBox(width: 12),
                           Expanded(child: Text(text, style: TextStyle(color: isNegative ? (isDark ? Colors.white38 : Colors.grey) : (isDark ? Colors.white : Colors.black)))),
                         ],
                       ),
                     );
                   }),
               ],
             ),
           )
        ],
      ),
    );
  }
}
