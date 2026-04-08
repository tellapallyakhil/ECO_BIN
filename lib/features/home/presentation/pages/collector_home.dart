import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/app_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../models/models.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../rewards/presentation/pages/rewards_page.dart';
import '../../../insights/presentation/pages/insights_page.dart';
import 'collection_completed_screen.dart';
import '../../../hardware/presentation/pages/live_hardware_page.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/location_service.dart';
import '../../../../core/constants.dart';

/// Opens a URL externally (Google Maps, browser, etc.)
Future<void> launchUrlExternally(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class CollectorHome extends ConsumerStatefulWidget {
  const CollectorHome({super.key});

  @override
  ConsumerState<CollectorHome> createState() => _CollectorHomeState();
}

class _CollectorHomeState extends ConsumerState<CollectorHome> {
  @override
  void initState() {
    super.initState();
    
    // Register notification tap callback for navigation
    NotificationService.onNavigateToBin = (lat, lng, location) {
      if (mounted) {
        _navigateToGoogleMaps(lat, lng, location);
      }
    };

    // 🔔 Register a background listener for the Sensor Data
    ref.listenManual(liveHardwareProvider, (previous, next) {
      next.whenData((data) async {
        if (data != null && data.weight >= AppConstants.fullAlertGrams) {
          // Trigger 200g FULL Alert with GPS location!
          await NotificationService.showFullBinAlert(
            binLocation: data.hasLocation
                ? 'GPS: ${data.latitude.toStringAsFixed(4)}, ${data.longitude.toStringAsFixed(4)}'
                : 'Eco Bin (Live Hardware)',
            binId: 'Hardware_Bin_01',
            latitude: data.latitude,
            longitude: data.longitude,
            weight: data.weight,
          );
        }
      });
    });

    // Check for full bins after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForFullBinAlerts();
    });
  }

  /// Open Google Maps for turn-by-turn navigation to the bin
  void _navigateToGoogleMaps(double lat, double lng, String label) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    // Use url_launcher or fallback
    try {
      // For web, open in new tab
      await launchUrlExternally(url.toString());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to: $label ($lat, $lng)')),
        );
      }
    }
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
          if (bins.isNotEmpty && bins.first.latitude != 0.0)
            ElevatedButton.icon(
              icon: const Icon(Icons.navigation, size: 18),
              label: const Text('Navigate'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(context);
                _navigateToGoogleMaps(bins.first.latitude, bins.first.longitude, bins.first.locationName ?? 'Bin');
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
    final filteredBinsAsync = ref.watch(filteredBinsProvider);
    final profileAsync = ref.watch(profileProvider);
    final claimedBins = ref.watch(claimedBinsProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? '';

    final name = profileAsync.whenOrNull<String>(data: (p) => p.fullName) ?? 'Collector';

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
              ref.invalidate(allBinsProvider);
              ref.invalidate(pendingCollectionsProvider);
              ref.invalidate(allUsersProvider);
              ref.invalidate(liveHardwareProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(name),
                  const SizedBox(height: 20),

                  // 🔴 LIVE HARDWARE WEIGHT CARD
                  _buildLiveWeightCard(),
                  const SizedBox(height: 24),

                  _buildUserList(ref.watch(allUsersProvider)),
                  const SizedBox(height: 24),

                  _buildPendingVerifications(ref.watch(pendingCollectionsProvider)),
                  const SizedBox(height: 24),

                  // Map preview
                  _buildMapPreview(context),
                  const SizedBox(height: 24),

                  // Area Selector
                  _buildAreaSelector(),
                  const SizedBox(height: 24),

                  // Bin List
                  _buildBinList(ref.watch(filteredBinsProvider), claimedBins, userId),
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

  /// 🔴 LIVE HARDWARE WEIGHT CARD — Shows real-time bin weight from ThingSpeak
  Widget _buildLiveWeightCard() {
    final hardwareAsync = ref.watch(liveHardwareProvider);
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monitor_weight, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Bin Weight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('Real-time data from hardware sensor', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              // Live pulse indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          hardwareAsync.when(
            data: (data) {
              if (data == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Waiting for sensor data...', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                  ),
                );
              }

              final weight = data.weight;
              final fillPct = data.fillPercentage;
              final statusColor = data.statusColor;
              final isFull = weight >= AppConstants.fullAlertGrams;

              return Column(
                children: [
                  // Weight display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${weight.toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: statusColor, height: 1),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('grams', style: TextStyle(fontSize: 14, color: statusColor.withValues(alpha: 0.7))),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          isFull ? '🚨 BIN FULL' : data.statusLabel,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fillPct,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0g', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
                      Text('${(fillPct * 100).toInt()}% of ${AppConstants.binCapacityGrams.toInt()}g capacity',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
                      Text('${AppConstants.binCapacityGrams.toInt()}g', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Details row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _WasteDetail(icon: Icons.scale, label: 'Weight', value: '${weight.toStringAsFixed(1)}g'),
                        Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                        _WasteDetail(icon: Icons.speed, label: 'Fill', value: '${(fillPct * 100).toInt()}%'),
                        Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                        _WasteDetail(
                          icon: Icons.location_on,
                          label: 'GPS',
                          value: data.hasLocation ? '${data.latitude.toStringAsFixed(2)}, ${data.longitude.toStringAsFixed(2)}' : 'N/A',
                        ),
                      ],
                    ),
                  ),

                  // Navigate button (only when full and has location)
                  if (isFull && data.hasLocation) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation, size: 18),
                        label: const Text('Navigate to Full Bin'),
                        onPressed: () => _navigateToGoogleMaps(data.latitude, data.longitude, 'Full Bin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Sensor error: $e', style: const TextStyle(color: AppTheme.errorColor, fontSize: 11)),
            ),
          ),
        ],
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
          error: (e, s) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildBinList(AsyncValue<List<SmartBin>> allBinsAsync, Map<String, String> claimedBins, String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('All Bins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Real-time waste data from hardware sensors', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        allBinsAsync.when(
          data: (bins) {
            final visibleBins = bins.where((bin) {
              final isFull = bin.fillPercentage >= 0.625;
              final claimant = claimedBins[bin.id];

              if (isFull) {
                return claimant == userId;
              }
              return true;
            }).toList();

            if (visibleBins.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.hub_outlined, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      const Text('Rest & Relax', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('No tasks assigned to you right now.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
              );
            }

            final sorted = List.from(visibleBins)..sort((a, b) => b.fillPercentage.compareTo(a.fillPercentage));
            return Column(
              children: sorted.map<Widget>((bin) => _buildBinDetailCard(bin, userId)).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, s) => Center(child: Text('Technical error: $e', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ),
      ],
    );
  }

  Widget _buildBinDetailCard(dynamic bin, String userId) {
    // Merge live ThingSpeak data with database data
    final liveData = ref.watch(liveHardwareProvider).value;
    
    // Use live weight (grams) if available, otherwise use DB weight (kg → grams)
    final liveWeightGrams = liveData?.weight ?? (bin.currentWeight * 1000);
    final liveFillPct = (liveWeightGrams / AppConstants.binCapacityGrams).clamp(0.0, 1.0);
    
    final pct = liveFillPct;
    final color = pct >= 0.625 ? AppTheme.errorColor : (pct >= 0.4 ? AppTheme.accentColor : AppTheme.primaryColor);
    final isFull = liveWeightGrams >= AppConstants.fullAlertGrams;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
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
                // Status badge with LIVE indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isFull ? '🚨 FULL' : (pct >= 0.4 ? 'FILLING' : 'OK'),
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (liveData != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 5, color: AppTheme.primaryColor),
                          const SizedBox(width: 3),
                          Text('LIVE', style: TextStyle(fontSize: 7, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Fill progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WasteDetail(icon: Icons.monitor_weight, label: 'Weight', value: '${liveWeightGrams.toStringAsFixed(1)}g'),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                  _WasteDetail(icon: Icons.speed, label: 'Capacity', value: '${AppConstants.binCapacityGrams.toInt()}g'),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                  _WasteDetail(icon: Icons.pie_chart, label: 'Fill', value: '${(pct * 100).toInt()}%'),
                ],
              ),
            ),
            if (pct >= 0.625) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping, size: 18),
                  label: const Text('Mark as Collected'),
                  onPressed: () async {
                    final coins = (bin.currentWeight * 50).toInt();
                    ref.read(claimedBinsProvider.notifier).claimBin(bin.id, userId);
                    
                    // 🔇 STOP BUZZER once accepted
                    await NotificationService.stopBuzzer();
                    
                    if (context.mounted) {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (_) => CollectionCompletedScreen(bin: bin, coins: coins)
                        )
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Bin ${bin.locationName ?? bin.id} marked as collected!')),
                      );
                    }
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
              return GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.checklist_rtl, size: 32, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 8),
                      Text('No pending verifications', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: requests.map((req) => _buildRequestCard(req)).toList(),
            );
          },
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
          error: (e, _) => GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error loading requests: ${e.toString()}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.errorColor),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => ref.invalidate(pendingCollectionsProvider),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(CollectionRequest req) {
    final timeStr = "${req.createdAt.hour}:${req.createdAt.minute.toString().padLeft(2, '0')}";
    final dateStr = "${req.createdAt.day}/${req.createdAt.month}";
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(timeStr, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(dateStr, style: TextStyle(color: AppTheme.primaryColor.withValues(alpha: 0.5), fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(req.userName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${DateTime.now().difference(req.createdAt).inMinutes}m ago', style: const TextStyle(color: AppTheme.accentColor, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.scale, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text('${req.weight.toStringAsFixed(1)} kg', 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(' • ${req.binLocation}', 
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.stars, size: 14),
              label: const Text('Award Coins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () => _showCoinAssignmentDialog(req),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoinAssignmentDialog(CollectionRequest req) {
    // Calculate coins based on weight in grams (0.5 coins per gram)
    final calculatedCoins = AppConstants.calculateCoins(req.weight);
    
    final coinsController = TextEditingController(text: '$calculatedCoins');
    final noteController = TextEditingController();
    final liveData = ref.read(liveHardwareProvider).value;
    final liveWeight = liveData?.weight ?? req.weight;
    final timestamp = DateTime.now();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.monetization_on, color: AppTheme.accentColor, size: 24),
            const SizedBox(width: 8),
            const Text('Award EcoCoins'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(req.userName ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const Icon(Icons.timer, size: 14, color: AppTheme.accentColor),
                    const SizedBox(width: 4),
                    Text(
                      "${req.createdAt.hour}:${req.createdAt.minute.toString().padLeft(2, '0')}", 
                      style: const TextStyle(fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Weight info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.scale, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text('Weight: ${liveWeight.toStringAsFixed(1)} g', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Coins field
              TextField(
                controller: coinsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'EcoCoins to Award',
                  hintText: 'Enter coin amount',
                  prefixIcon: Icon(Icons.stars),
                ),
              ),
              const SizedBox(height: 12),

              // Note field (mandatory)
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason / Note *',
                  hintText: 'e.g. Deposited 450g of plastic bottles',
                  prefixIcon: Icon(Icons.note_add),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve & Award'),
            onPressed: () async {
              final coins = int.tryParse(coinsController.text) ?? 0;
              final note = noteController.text.trim();
              
              if (coins <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid coin amount')),
                );
                return;
              }
              if (note.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please add a note explaining the reward')),
                );
                return;
              }

              try {
                final supabase = ref.read(supabaseProvider);
                
                // 1. Update user coins (Verified Update)
                final userProfile = await supabase.from('profiles').select('coins').eq('id', req.userId).maybeSingle();
                final currentCoins = (userProfile?['coins'] ?? 0) as int;
                
                final updateResult = await supabase.from('profiles')
                    .update({'coins': currentCoins + coins})
                    .eq('id', req.userId)
                    .select();
                
                if (updateResult.isEmpty) {
                  throw Exception('Permission Denied: Database prevented balance update. Only the user or an admin can update coins.');
                }

                // 2. Log transaction with note, weight, and timestamp
                await supabase.from('coin_transactions').insert({
                  'user_id': req.userId,
                  'amount': coins,
                  'type': 'reward',
                  'description': note,
                  'weight': liveWeight,
                });

                // 3. Mark request as approved
                await supabase.from('collection_requests').update({'status': 'approved'}).eq('id', req.id);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
                  ref.invalidate(pendingCollectionsProvider);
                  ref.invalidate(allUsersProvider);
                  // Ensure the profile stream refreshes across all views
                  ref.invalidate(profileProvider);
                  ref.invalidate(coinTransactionsProvider);
                  ref.invalidate(allBinsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 $coins EcoCoins awarded to ${req.userName}!'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveHardwarePage())),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Column(
                children: [
                  Icon(Icons.sensors, color: AppTheme.primaryColor, size: 28),
                  SizedBox(height: 8),
                  Text('Live Sensor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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

  Widget _buildUserList(AsyncValue<List<AppUser>> usersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.people_alt_outlined, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 8),
                Text('Registered Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
              onPressed: () => ref.invalidate(allUsersProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        usersAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('No customers registered', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
                ),
              );
            }
            return Column(
              children: users.map((user) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Text(
                          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 4),
                                Text('[ID: ${user.id.substring(0, 4)}]', style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.3))),
                              ],
                            ),
                            Text('${user.coins} EcoCoins', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Reward', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showManualCoinAwardDialog(user),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            );
          },
          loading: () => const Center(child: LinearProgressIndicator(minHeight: 2)),
          error: (e, _) => Text('Error loading users: $e', style: const TextStyle(color: AppTheme.errorColor, fontSize: 11)),
        ),
      ],
    );
  }

  void _showManualCoinAwardDialog(AppUser user) {
    final coinsController = TextEditingController();
    final noteController = TextEditingController();
    final liveData = ref.read(liveHardwareProvider).value;
    final liveWeight = liveData?.weight ?? 0.0;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stars, color: AppTheme.accentColor, size: 24),
            const SizedBox(width: 8),
            const Text('Manual Reward'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Awarding: ${user.fullName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.scale, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text('Live Hardware Weight: ${liveWeight.toStringAsFixed(1)}g'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: coinsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'EcoCoins to Award',
                  prefixIcon: Icon(Icons.stars),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for Reward',
                  hintText: 'e.g. Deposited 5 bottles',
                  prefixIcon: Icon(Icons.note_add),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final coins = int.tryParse(coinsController.text) ?? 0;
              final note = noteController.text.trim();
              if (coins <= 0) return;
              
              try {
                final supabase = ref.read(supabaseProvider);
                
                // 1. Get current coins (Verified Update)
                final currentCoinsResponse = await supabase.from('profiles').select('coins').eq('id', user.id).single();
                final currentCoins = (currentCoinsResponse['coins'] ?? 0) as int;
                
                // 2. Perform Verified Update
                final updateResult = await supabase.from('profiles')
                    .update({'coins': currentCoins + coins})
                    .eq('id', user.id)
                    .select();
                
                if (updateResult.isEmpty) {
                  throw Exception('Database REFUSED to update balance. Please check your Supabase RLS policies for profiles!');
                }

                // 3. Log transaction
                await supabase.from('coin_transactions').insert({
                  'user_id': user.id,
                  'amount': coins,
                  'type': 'reward',
                  'description': note.isNotEmpty ? note : 'Manual EcoBin collection',
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                
                if (mounted) {
                  // CRITICAL: Refresh the user list so the 100 coins appear instantly!
                  ref.invalidate(allUsersProvider);
                  ref.invalidate(profileProvider);
                  ref.invalidate(coinTransactionsProvider);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ $coins Coins awarded to ${user.fullName}!')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Award Now'),
          ),
        ],
      ),
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
