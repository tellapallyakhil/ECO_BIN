import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../models/models.dart';

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsProvider);
    final profileAsync = ref.watch(profileProvider);
    final coins = profileAsync.whenOrNull<int>(data: (p) => p.coins) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards Marketplace'),
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
        child: Column(
          children: [
            // Coins balance header
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor.withValues(alpha: 0.2), AppTheme.primaryColor.withValues(alpha: 0.05)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: AppTheme.accentColor, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('$coins EcoCoins', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            // Rewards list
            Expanded(
              child: rewardsAsync.when(
                data: (rewards) => ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rewards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    final canAfford = coins >= reward.cost;

                    return GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.card_giftcard, color: AppTheme.accentColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(reward.description, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                                const SizedBox(height: 6),
                                Text(
                                  '${reward.cost} Coins  •  ${reward.sponsor}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: canAfford ? () => _redeemReward(context, ref, reward) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAfford ? AppTheme.primaryColor : Colors.grey.shade800,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: const Text('Redeem', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading rewards: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _redeemReward(BuildContext context, WidgetRef ref, Reward reward) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Redeem Reward'),
        content: Text('Spend ${reward.cost} EcoCoins to get "${reward.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🎉 Redeemed: ${reward.title}')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
