import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../models/models.dart';
import '../../../insights/presentation/pages/insights_page.dart';
import '../../../rewards/presentation/pages/rewards_page.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../public/presentation/pages/qr_scanner_screen.dart';
import '../../../hardware/presentation/pages/live_hardware_page.dart';
import '../../../../services/location_service.dart';

class CustomerHome extends ConsumerStatefulWidget {
  const CustomerHome({super.key});

  @override
  ConsumerState<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends ConsumerState<CustomerHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFullBinNotification();
      // 📍 Sync current location as the bin location
      LocationService.syncBinLocationWithUser();
    });
  }

  void _checkFullBinNotification() async {
    try {
      final bins = await ref.read(userBinsProvider.future);
      final fullBins = bins.where((b) => b.fillPercentage >= 0.85).toList();
      if (fullBins.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔔 ${fullBins.length} of your bins are almost full! Collection has been notified.'),
            duration: const Duration(seconds: 4),
            backgroundColor: AppTheme.errorColor.withValues(alpha: 0.9),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final binsAsync = ref.watch(userBinsProvider);

    final name = profileAsync.whenOrNull<String>(data: (p) => p.fullName) ?? 'User';
    final coins = profileAsync.whenOrNull<int>(data: (p) => p.coins) ?? 0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1B2A4A), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileProvider);
              ref.invalidate(userBinsProvider);
              ref.invalidate(coinTransactionsProvider);
              ref.invalidate(leaderboardProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(name, ref.watch(currentUserProvider)?.id ?? ''),
                  const SizedBox(height: 24),
                  _buildWalletCard(coins),
                  const SizedBox(height: 24),
                  _buildRewardTimeline(),
                  const SizedBox(height: 24),
                  _buildBinSection(binsAsync),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildEcoInsights(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name, String id) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              Row(
                children: [
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('[ID: ${id.substring(0, 4)}]', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.2))),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            // Camera / QR Scanner for Bin Scanning
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen())),
            ),
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                child: const Icon(Icons.person, color: AppTheme.primaryColor),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  ref.invalidate(profileProvider);
                  ref.invalidate(userBinsProvider);
                  await signOut();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'logout', child: Text('Sign Out')),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletCard(int coins) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.monetization_on, color: AppTheme.accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('EcoCoins', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.sync, size: 14, color: AppTheme.primaryColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref.invalidate(profileProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refreshing balance...'), duration: Duration(milliseconds: 500)),
                        );
                      },
                    ),
                  ],
                ),
                Text('$coins', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage())),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Redeem', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardTimeline() {
    final transactionsAsync = ref.watch(coinTransactionsProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timeline, color: AppTheme.accentColor, size: 20),
            const SizedBox(width: 8),
            const Text('Reward Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('Recent', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 4),
        Text('Points awarded by workers for your deposits', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 40, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 12),
                      const Text('No rewards yet', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Deposit waste to earn EcoCoins!', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: transactions.take(5).map((tx) {
                final amount = (tx['amount'] as num?)?.toInt() ?? 0;
                final description = tx['description']?.toString() ?? 'Reward';
                final weight = (tx['weight'] as num?)?.toDouble();
                final createdAt = DateTime.tryParse(tx['created_at'] ?? '') ?? DateTime.now();
                final timeAgo = _formatTimeAgo(createdAt);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline dot
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.stars, color: AppTheme.accentColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('+$amount', style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accentColor,
                                  )),
                                  const Text(' EcoCoins', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const Spacer(),
                                  Text(timeAgo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Worker's note
                              Text(description, style: TextStyle(
                                fontSize: 13, color: Colors.white.withValues(alpha: 0.7),
                              )),
                              if (weight != null && weight > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('⚖️ ${weight.toStringAsFixed(0)}g deposited',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildBinSection(AsyncValue<List<SmartBin>> binsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Smart Bins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Live waste data from hardware sensors', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        binsAsync.when(
          data: (bins) {
            if (bins.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.sensors_off_outlined, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      const Text('No hardware connected', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Connect your EcoBin smart device to see real-time data.',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: bins.map<Widget>((bin) => _buildBinCard(bin)).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Center(child: Text('Technical error: $e', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ),
      ],
    );
  }
  Widget _buildBinCard(dynamic bin) {
    final pct = bin.fillPercentage as double;
    // Color logic: Green(0-80g=40%), Orange(80-125g=62.5%), Red(125g+=62.5%+)
    final color = pct >= 0.625 ? AppTheme.errorColor : (pct >= 0.4 ? AppTheme.accentColor : AppTheme.primaryColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Column(
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(bin.locationName ?? 'Location pending', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bin #${bin.id.toString().length > 12 ? bin.id.toString().substring(0, 12) : bin.id}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pct >= 0.625 ? '⚠️ FULL' : 'ACTIVE',
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Circular progress
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 110,
                  width: 110,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: color,
                  ),
                ),
                Column(
                  children: [
                    Text('${(pct * 100).toInt()}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                    const Text('Full', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Waste data details
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSensorData(Icons.monitor_weight, 'Weight', '${bin.currentWeight} kg', color),
                  Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.1)),
                  _buildSensorData(Icons.speed, 'Threshold', '${bin.threshold} kg', Colors.grey),
                  Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.1)),
                  _buildSensorData(Icons.pie_chart, 'Fill', '${(pct * 100).toInt()}%', color),
                ],
              ),
            ),

            // Alert if full
            if (pct >= 0.625) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.errorColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Municipal collector has been notified. Collection is on the way!',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSensorData(IconData icon, String label, String value, Color valueColor) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.sensors,
                label: 'Live Hardware',
                color: AppTheme.primaryColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveHardwarePage())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.map_outlined,
                label: 'Bin Map',
                color: AppTheme.secondaryColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.card_giftcard,
                label: 'Rewards',
                color: AppTheme.accentColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage())),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEcoInsights() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsightsPage())),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.public, color: Colors.blue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Eco Insights', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                  const Text(AppConstants.dailyPlasticWaste, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
