import 'package:flutter/material.dart';
import '../utils/iap_manager.dart';
import '../utils/sound_manager.dart';
import '../widgets/cosmic_button.dart';
import '../widgets/cosmic_snackbar.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E27),
              Color(0xFF2A0F38), // Purple tint for premium feel
              Color(0xFF0A0E27),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildBenefitsCard(),
                      const SizedBox(height: 30),
                      const Text(
                        "CHOOSE YOUR PLAN",
                        style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: Colors.white,
                            fontSize: 20,
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 20),
                      _buildPriceCard(
                        context,
                        title: "Weekly",
                        price: "₹20 / week",
                        productId: "premium_weekly",
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(height: 15),
                      _buildPriceCard(
                        context,
                        title: "Monthly",
                        price: "₹50 / month",
                        productId: "premium_monthly",
                        color: Colors.purpleAccent,
                        isPopular: true,
                      ),
                      const SizedBox(height: 15),
                      _buildPriceCard(
                        context,
                        title: "Yearly",
                        price: "₹200 / year",
                        productId: "premium_yearly",
                        color: Colors.amberAccent,
                        savings: "Best Value",
                      ),
                      const SizedBox(height: 30),
                      TextButton(
                        onPressed: () {
                           IAPManager.instance.restorePurchases();
                        },
                        child: const Text(
                          "Restore Purchases",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'GET PREMIUM',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.amberAccent,
              letterSpacing: 1.2,
              fontFamily: 'Orbitron',
              shadows: [Shadow(color: Colors.amber, blurRadius: 10)],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () {
                SoundManager().playClick();
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
            _buildBenefitRow(Icons.block, "Remove all Ads"),
            const SizedBox(height: 15),
            _buildBenefitRow(Icons.lightbulb_outline, "Unlimited Hints"),
            const SizedBox(height: 15),
            _buildBenefitRow(Icons.replay, "Unlimited Second Chances"),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.amberAccent, size: 28),
        const SizedBox(width: 15),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPriceCard(
    BuildContext context, {
    required String title,
    required String price,
    required String productId,
    required Color color,
    bool isPopular = false,
    String? savings,
  }) {
    return GestureDetector(
      onTap: () async {
        SoundManager().playClick();
        await IAPManager.instance.purchaseProduct(productId);
        // Since we can't really pay in simulator, we show a message
        if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Initiating Google Play purchase flow...")),
             );
        }
      },
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isPopular ? color : Colors.white10, width: isPopular ? 2 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (savings != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 4),
                     child: Text(
                       savings,
                       style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                     ),
                   )
              ],
            ),
            const Spacer(),
            Text(
              price,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
