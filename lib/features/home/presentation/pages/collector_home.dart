import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../models/models.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../rewards/presentation/pages/rewards_page.dart';
import '../../../insights/presentation/pages/insights_page.dart';
import 'collection_completed_screen.dart';

class CollectorHome extends ConsumerStatefulWidget {
  const CollectorHome({super.key});

  @override
  ConsumerState<CollectorHome> createState() => _CollectorHomeState();
}

class _CollectorHomeState extends ConsumerState<CollectorHome> {
  @override
  void initState() {
    super.initState();
    // Check for full bins after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForFullBinAlerts();
    });
  }

  void _checkForFullBinAlerts() async {
    try {
      final alertBins = await ref.read(alertBinsProvider.future);
      if (alertBins.isNotEmpty && mounted) {
        _showBinAlert(alertBins);
      }
    } catch (_) {}
  }

  void _showBinAlert(List bins) {
    // Play alert sound 3 times for urgency
    _playAlertSound();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notification_important, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 12),
            const Text('⚠️ Bin Alert!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${bins.length} bin(s) need immediate collection:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            ...bins.take(5).map((bin) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: AppTheme.errorColor, size: 10),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bin.locationName ?? 'Unknown Location',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${bin.currentWeight} kg / ${bin.threshold} kg  (${(bin.fillPercentage * 100).toInt()}% Full)',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.map, size: 18),
            label: const Text('View on Map'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage()));
            },
          ),
        ],
      ),
    );
  }

  void _playAlertSound() async {
    // Play system alert sound 3 times with delay
    for (int i = 0; i < 3; i++) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final allBinsAsync = ref.watch(allBinsProvider);
    final alertBinsAsync = ref.watch(alertBinsProvider);

    final name = profileAsync.whenOrNull<String>(data: (p) => p.fullName) ?? 'Collector';
    final coins = profileAsync.whenOrNull<int>(data: (p) => p.coins) ?? 0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1A2744), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileProvider);
              ref.invalidate(allBinsProvider);
              ref.invalidate(alertBinsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(name),
                  const SizedBox(height: 24),

                  // Stats Row
                  _buildStatsRow(coins, allBinsAsync, alertBinsAsync),
                  const SizedBox(height: 24),

                  // Alert Banner
                  _buildAlertBanner(alertBinsAsync),

                  // Pending Verifications (Manual Coin Assignment)
                  _buildPendingVerifications(ref.watch(pendingCollectionsProvider)),
                  const SizedBox(height: 24),

                  // Map preview
                  _buildMapPreview(context),
                  const SizedBox(height: 24),

                  // Area Selector
                  _buildAreaSelector(),
                  const SizedBox(height: 24),

                  // Bin List
                  _buildBinList(ref.watch(filteredBinsProvider)),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, color: AppTheme.accentColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'GOVT WORKER',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Row(
          children: [
            // Notification Bell
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppTheme.accentColor),
              onPressed: _checkForFullBinAlerts,
            ),
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
                child: const Icon(Icons.person, color: AppTheme.accentColor),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  ref.invalidate(profileProvider);
                  ref.invalidate(allBinsProvider);
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

  Widget _buildStatsRow(int coins, AsyncValue<List> allBinsAsync, AsyncValue<List> alertBinsAsync) {
    final totalBins = allBinsAsync.whenOrNull<int>(data: (b) => b.length) ?? 0;
    final fullBins = alertBinsAsync.whenOrNull<int>(data: (b) => b.length) ?? 0;

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Waste Managed', value: '0 kg', icon: Icons.scale_outlined, color: AppTheme.accentColor)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Total Bins', value: '$totalBins', icon: Icons.delete_outline, color: AppTheme.secondaryColor)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Alerts', value: '$fullBins', icon: Icons.warning_amber, color: fullBins > 0 ? AppTheme.errorColor : AppTheme.primaryColor)),
      ],
    );
  }

  Widget _buildAlertBanner(AsyncValue<List> alertBinsAsync) {
    final alertCount = alertBinsAsync.whenOrNull<int>(data: (b) => b.length) ?? 0;
    if (alertCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.errorColor.withValues(alpha: 0.2), AppTheme.errorColor.withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.notification_important, color: AppTheme.errorColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$alertCount bin(s) need collection!', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('These bins have crossed 85% capacity.', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage())),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.map, color: AppTheme.secondaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('View Bin Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('See all bin locations & waste levels', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaSelector() {
    final areasAsync = ref.watch(availableAreasProvider);
    final currentFilter = ref.watch(collectorAreaFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose Area / Zone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        areasAsync.when(
          data: (areas) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: areas.map((area) {
                final isSelected = (currentFilter == area) || (currentFilter == null && area == 'All Areas');
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(area),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(collectorAreaFilterProvider.notifier).setArea(area == 'All Areas' ? null : area);
                    },
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }).toList(),
            ),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildBinList(AsyncValue<List<SmartBin>> allBinsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('All Bins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Real-time waste data from hardware sensors', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        allBinsAsync.when(
          data: (bins) {
            if (bins.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.hub_outlined, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text('No bins registered in this area', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              );
            }
            final sorted = List.from(bins)..sort((a, b) => b.fillPercentage.compareTo(a.fillPercentage));
            return Column(
              children: sorted.map<Widget>((bin) => _buildBinDetailCard(bin)).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Center(child: Text('Technical error: $e', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ),
      ],
    );
  }
  Widget _buildBinDetailCard(dynamic bin) {
    final pct = bin.fillPercentage;
    final color = pct >= 0.85 ? AppTheme.errorColor : (pct >= 0.6 ? AppTheme.accentColor : AppTheme.primaryColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Fill indicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 60,
                      width: 60,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        color: color,
                      ),
                    ),
                    Text('${(pct * 100).toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
                const SizedBox(width: 16),
                // Bin info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              bin.locationName ?? 'Unknown Location',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bin #${bin.id.toString().length > 10 ? bin.id.toString().substring(0, 10) : bin.id}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pct >= 0.85 ? '⚠️ FULL' : (pct >= 0.6 ? 'FILLING' : 'OK'),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Waste details row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WasteDetail(icon: Icons.monitor_weight, label: 'Weight', value: '${bin.currentWeight} kg'),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                  _WasteDetail(icon: Icons.speed, label: 'Threshold', value: '${bin.threshold} kg'),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                  _WasteDetail(icon: Icons.solar_power, label: 'Solar', value: '92%'),
                ],
              ),
            ),
            if (pct >= 0.85) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping, size: 18),
                  label: const Text('Mark as Collected'),
                  onPressed: () {
                    final coins = (bin.currentWeight * 50).toInt();
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => CollectionCompletedScreen(bin: bin, coins: coins)
                      )
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Bin ${bin.locationName ?? bin.id} marked as collected!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingVerifications(AsyncValue<List<CollectionRequest>> requestsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pending Verifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Verify waste deposits & manually award coins', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              children: requests.map((req) => _buildRequestCard(req)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRequestCard(CollectionRequest req) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history_edu, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.userName ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${req.weight.toStringAsFixed(1)} kg dropped at ${req.binLocation}', 
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _showCoinAssignmentDialog(req),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Award Coins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoinAssignmentDialog(CollectionRequest req) {
    final controller = TextEditingController(text: '${(req.weight * 10).toInt()}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Assign EcoCoins'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${req.userName}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text('Waste Weight: ${req.weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'EcoCoins to Award',
                hintText: 'Enter amount',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final coins = int.tryParse(controller.text) ?? 0;
              if (coins > 0) {
                try {
                  final supabase = ref.read(supabaseProvider);
                  
                  // 1. Update user coins
                  final userProfile = await supabase.from('profiles').select('coins').eq('id', req.userId).maybeSingle();
                  final currentCoins = (userProfile?['coins'] ?? 0) as int;

                  await supabase.from('profiles').update({'coins': currentCoins + coins}).eq('id', req.userId);

                  // 2. Log transaction
                  await supabase.from('coin_transactions').insert({
                    'user_id': req.userId,
                    'amount': coins,
                    'type': 'reward',
                    'description': 'Awarded for ${req.weight.toStringAsFixed(1)} kg at ${req.binLocation}',
                  });

                  // 3. Mark request as approved
                  await supabase.from('collection_requests').update({'status': 'approved'}).eq('id', req.id);

                  if (mounted) {
                    Navigator.pop(context);
                    ref.invalidate(pendingCollectionsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ $coins Coins awarded to ${req.userName}!')),
                    );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage())),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Column(
                children: [
                  Icon(Icons.card_giftcard, color: AppTheme.accentColor, size: 28),
                  SizedBox(height: 8),
                  Text('Rewards', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsightsPage())),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Column(
                children: [
                  Icon(Icons.public, color: AppTheme.secondaryColor, size: 28),
                  SizedBox(height: 8),
                  Text('Eco Impact', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _WasteDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WasteDetail({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
