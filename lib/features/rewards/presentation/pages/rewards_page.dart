import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../models/models.dart';

// ═══════════════════════════════════════════════════════════════
//  USER TIER SYSTEM — Based on lifetime EcoCoins earned
// ═══════════════════════════════════════════════════════════════
class UserTier {
  final String name;
  final IconData icon;
  final Color color;
  final int minCoins;
  final double bonusMultiplier;

  const UserTier({
    required this.name,
    required this.icon,
    required this.color,
    required this.minCoins,
    required this.bonusMultiplier,
  });

  static UserTier fromCoins(int totalCoins) {
    if (totalCoins >= 5000) return platinum;
    if (totalCoins >= 2000) return gold;
    if (totalCoins >= 500) return silver;
    return bronze;
  }

  static UserTier get nextTier => bronze; // placeholder used below

  static const bronze = UserTier(
    name: 'Bronze',
    icon: Icons.shield_outlined,
    color: Color(0xFFCD7F32),
    minCoins: 0,
    bonusMultiplier: 1.0,
  );

  static const silver = UserTier(
    name: 'Silver',
    icon: Icons.shield,
    color: Color(0xFFC0C0C0),
    minCoins: 500,
    bonusMultiplier: 1.2,
  );

  static const gold = UserTier(
    name: 'Gold',
    icon: Icons.workspace_premium,
    color: Color(0xFFFFD700),
    minCoins: 2000,
    bonusMultiplier: 1.5,
  );

  static const platinum = UserTier(
    name: 'Platinum',
    icon: Icons.diamond,
    color: Color(0xFFE5E4E2),
    minCoins: 5000,
    bonusMultiplier: 2.0,
  );

  static const allTiers = [bronze, silver, gold, platinum];

  UserTier? getNextTier() {
    final idx = allTiers.indexOf(this);
    if (idx < allTiers.length - 1) return allTiers[idx + 1];
    return null;
  }
}

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
    _tabController = TabController(length: 3, vsync: this);
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
    final tier = UserTier.fromCoins(coins);

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
            Tab(icon: Icon(Icons.leaderboard_outlined), text: 'Leaderboard'),
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
            // ─── WALLET & TIER HEADER ───
            _buildWalletHeader(coins, tier),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMarketplaceTab(ref, coins),
                  _buildHistoryTab(ref),
                  _buildLeaderboardTab(ref),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WALLET & TIER HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildWalletHeader(int coins, UserTier tier) {
    final nextTier = tier.getNextTier();
    final progressToNext = nextTier != null
        ? ((coins - tier.minCoins) / (nextTier.minCoins - tier.minCoins)).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tier.color.withValues(alpha: 0.25),
            tier.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tier.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Tier Badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tier.icon, color: tier.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${tier.name} Tier',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: tier.color,
                            letterSpacing: 1,
                          ),
                        ),
                        if (tier.bonusMultiplier > 1.0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${tier.bonusMultiplier}x bonus',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$coins EcoCoins',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Progress to next tier
          if (nextTier != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '${nextTier.minCoins - coins} coins to ${nextTier.name}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progressToNext * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tier.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressToNext,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: tier.color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MARKETPLACE TAB — Real redemption with Supabase
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMarketplaceTab(WidgetRef ref, int coins) {
    final rewardsAsync = ref.watch(rewardsProvider);
    return rewardsAsync.when(
      data: (rewards) {
        if (rewards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                const Text('Marketplace Coming Soon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Add rewards in your Supabase "rewards" table.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
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
                      color: canAfford
                          ? AppTheme.accentColor.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.card_giftcard,
                      color: canAfford ? AppTheme.accentColor : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          reward.description,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on, size: 14, color: AppTheme.accentColor),
                            const SizedBox(width: 4),
                            Text(
                              '${reward.cost} Coins',
                              style: const TextStyle(fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${reward.sponsor}',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                            ),
                          ],
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
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HISTORY TAB
  // ═══════════════════════════════════════════════════════════════
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
                Text('Rewards will appear here after deposits and redemptions.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
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
            final desc = tx['description']?.toString() ?? 'Transaction';
            final type = tx['type']?.toString() ?? 'reward';
            final weight = (tx['weight'] as num?)?.toDouble() ?? 0;
            final date = DateTime.tryParse(tx['created_at'] ?? '') ?? DateTime.now();
            final isRedemption = type == 'redemption';

            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isRedemption ? AppTheme.errorColor : AppTheme.primaryColor).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRedemption ? Icons.shopping_cart : Icons.add_circle,
                      color: isRedemption ? AppTheme.errorColor : AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(desc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (weight > 0) ...[
                              Text('${weight.toStringAsFixed(0)}g', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                              Text(' • ', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                            ],
                            Text(
                              '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Text(
                    '${isRedemption ? '-' : '+'}$amount',
                    style: TextStyle(
                      color: isRedemption ? AppTheme.errorColor : AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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

  // ═══════════════════════════════════════════════════════════════
  //  LEADERBOARD TAB — Ranked by coins
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLeaderboardTab(WidgetRef ref) {
    final usersAsync = ref.watch(leaderboardProvider);

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                const Text('No rankings yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final rank = index + 1;
            final tier = UserTier.fromCoins(user.coins);

            // Top 3 get special styling
            Color rankColor;
            IconData? rankIcon;
            if (rank == 1) {
              rankColor = const Color(0xFFFFD700);
              rankIcon = Icons.emoji_events;
            } else if (rank == 2) {
              rankColor = const Color(0xFFC0C0C0);
              rankIcon = Icons.emoji_events;
            } else if (rank == 3) {
              rankColor = const Color(0xFFCD7F32);
              rankIcon = Icons.emoji_events;
            } else {
              rankColor = Colors.grey;
              rankIcon = null;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Rank
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rankColor.withValues(alpha: rank <= 3 ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: rankIcon != null
                            ? Icon(rankIcon, color: rankColor, size: 20)
                            : Text(
                                '#$rank',
                                style: TextStyle(
                                  color: rankColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Name & Tier
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(tier.icon, size: 12, color: tier.color),
                              const SizedBox(width: 4),
                              Text(
                                tier.name,
                                style: TextStyle(fontSize: 11, color: tier.color),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Coins
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${user.coins}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.accentColor,
                          ),
                        ),
                        Text(
                          'EcoCoins',
                          style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  REAL REDEMPTION — Deducts coins + logs transaction
  // ═══════════════════════════════════════════════════════════════
  void _redeemReward(BuildContext context, WidgetRef ref, Reward reward) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.card_giftcard, color: AppTheme.accentColor),
            const SizedBox(width: 8),
            const Text('Confirm Redemption'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reward.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              reward.description,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: AppTheme.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${reward.cost} EcoCoins will be deducted',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _executeRedemption(dialogCtx, ref, reward),
            child: const Text('Redeem Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRedemption(BuildContext dialogCtx, WidgetRef ref, Reward reward) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // 1. Re-fetch current balance to avoid race conditions
      final profileData = await supabase
          .from('profiles')
          .select('coins')
          .eq('id', user.id)
          .maybeSingle();

      final currentCoins = (profileData?['coins'] ?? 0) as int;
      if (currentCoins < reward.cost) {
        if (dialogCtx.mounted) {
          Navigator.pop(dialogCtx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Insufficient EcoCoins')),
          );
        }
        return;
      }

      // 2. Deduct coins
      await supabase
          .from('profiles')
          .update({'coins': currentCoins - reward.cost})
          .eq('id', user.id);

      // 3. Log redemption transaction
      await supabase.from('coin_transactions').insert({
        'user_id': user.id,
        'amount': -reward.cost,
        'type': 'redemption',
        'description': 'Redeemed: ${reward.title} (${reward.sponsor})',
      });

      // 4. Refresh all data
      ref.invalidate(profileProvider);
      ref.invalidate(coinTransactionsProvider);

      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
      }
      if (mounted) {
        _showRedemptionSuccess(reward);
      }
    } catch (e) {
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Redemption failed: $e')),
        );
      }
    }
  }

  void _showRedemptionSuccess(Reward reward) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.2),
                    AppTheme.accentColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 56, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            const Text('🎉 Redeemed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              reward.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Sponsored by ${reward.sponsor}',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('Show this to the merchant', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                  const SizedBox(height: 8),
                  SelectableText(
                    'ECO-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
