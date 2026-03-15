import 'package:flutter/material.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Impact'),
        backgroundColor: AppTheme.surfaceColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surfaceColor, AppTheme.backgroundColor],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('World Plastic Crisis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              _buildStatCard(
                Icons.delete_outline, 'Total Annual Waste', '220M Tons',
                'Projected for 2024 worldwide.', Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                Icons.warning_amber, 'Mismanaged Waste', '69.5M Tons',
                'Ends up in natural environments yearly.', Colors.red,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                Icons.water_drop, 'Ocean Leakage', '2000 Trucks/Day',
                'Equivalent plastic dumped into oceans daily.', Colors.blue,
              ),

              const SizedBox(height: 32),
              const Text('How EcoBin Helps', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppConstants.impactTitle,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConstants.impactDescription,
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    const Text('Key Impact Drivers:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    _buildMetric('Waste Segregation', '↑ 45%'),
                    _buildMetric('Collection Speed', '↑ 3x Faster'),
                    _buildMetric('Public Participation', '↑ 60%'),
                    _buildMetric('Plastic Recycled at Source', '50%'),
                    _buildMetric('CO₂ Emission Reduction', '↓ 25%'),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb, color: AppTheme.accentColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Smart solar-powered bins use weight sensors to track plastic '
                              'in real-time. Municipal offices get notified automatically '
                              'when bins reach 85% capacity.',
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, String desc, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }
}
