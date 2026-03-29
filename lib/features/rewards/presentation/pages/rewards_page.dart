import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../models/models.dart';

class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final coins = profileAsync.whenOrNull<int>(data: (p) => p.coins) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoCoins Central'),
        backgroundColor: AppTheme.surfaceColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Marketplace'),
            Tab(icon: Icon(Icons.history_outlined), text: 'History'),
          ],
        ),
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
                      const Text('Current Balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('$coins EcoCoins', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMarketplaceTab(ref, coins),
                  _buildHistoryTab(ref),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceTab(WidgetRef ref, int coins) {
    final rewardsAsync = ref.watch(rewardsProvider);
    return rewardsAsync.when(
      data: (rewards) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: rewards.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
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
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildHistoryTab(WidgetRef ref) {
    final transactionsAsync = ref.watch(coinTransactionsProvider);
    
    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                const Text('No transaction history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Rewards will appear here after collection.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final amount = (tx['amount'] as num?)?.toInt() ?? 0;
            final desc = tx['description']?.toString() ?? 'Reward';
            final weight = (tx['weight'] as num?)?.toDouble() ?? 0;
            final date = DateTime.tryParse(tx['created_at'] ?? '') ?? DateTime.now();
            
            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text('${date.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_getMonthName(date.month), style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  const VerticalDivider(color: Colors.white10),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(desc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (weight > 0) ...[
                          const SizedBox(height: 4),
                          Text('Recorded Weight: ${weight.toStringAsFixed(1)}g', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ],
                    ),
                  ),
                  Text('+$amount', style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('History error: $e')),
    );
  }

  String _getMonthName(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
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

