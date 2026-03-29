import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../providers/app_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../services/thingspeak_service.dart';

class LiveHardwarePage extends ConsumerWidget {
  const LiveHardwarePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveData = ref.watch(liveHardwareProvider);
    final historyAsync = ref.watch(hardwareHistoryProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0F1E), Color(0xFF0F1B33), Color(0xFF0A0F1E)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(latestHardwareProvider);
              ref.invalidate(hardwareHistoryProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context),
                  const SizedBox(height: 24),

                  // Connection Status
                  _buildConnectionStatus(liveData),
                  const SizedBox(height: 20),

                  // Main data card
                  liveData.when(
                    data: (data) => data != null
                        ? _buildLiveDataCard(data)
                        : _buildNoDataCard(),
                    loading: () => _buildLoadingCard(),
                    error: (e, s) => _buildErrorCard(),
                  ),
                  const SizedBox(height: 20),

                  // Sensor Grid
                  liveData.when(
                    data: (data) => data != null
                        ? _buildSensorGrid(data)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  // Weight Chart
                  const Text('Weight History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Last 50 readings from hardware sensor',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                  const SizedBox(height: 16),
                  historyAsync.when(
                    data: (history) => _buildWeightChart(history),
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (e, s) => const SizedBox(
                      height: 200,
                      child: Center(child: Text('Could not load history', style: TextStyle(color: Colors.grey))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // GPS Info
                  liveData.when(
                    data: (data) => data != null
                        ? _buildGPSCard(data)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Hardware',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Text('ESP32 → ThingSpeak → App',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
              Text('LIVE', style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus(AsyncValue<ThingSpeakBinData?> liveData) {
    final isConnected = liveData.whenOrNull(data: (d) => d != null) ?? false;
    final color = isConnected ? AppTheme.primaryColor : Colors.orange;
    final label = isConnected ? 'Hardware Connected' : 'Waiting for data...';
    final icon = isConnected ? Icons.link : Icons.link_off;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          Text('ThingSpeak CH: 3317901',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildLiveDataCard(ThingSpeakBinData data) {
    final pct = data.fillPercentage;
    final color = data.statusColor; // Using our new model color
    
    String label = 'SAFE';
    if (data.weight >= 600) label = 'FULL';
    else if (data.weight >= 300) label = 'HALF';
    else label = 'EMPTY';

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bin Status', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(data.statusLabel,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ],
              ),
              // Circular gauge
              SizedBox(
                width: 90, height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90, height: 90,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        color: color,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(pct * 100).toInt()}%',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                        Text('fill', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Weight display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.03)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.monitor_weight, color: color, size: 28),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Weight',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                    const SizedBox(height: 2),
                    Text('${data.weight.toStringAsFixed(1)} g',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Text('${data.weightKg.toStringAsFixed(3)} kg',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Last updated
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 4),
              Text(
                'Updated: ${_formatTime(data.createdAt)}',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid(ThingSpeakBinData data) {
    return Row(
      children: [
        Expanded(child: _sensorTile(Icons.thermostat, 'Status Code', '${data.status}',
            data.status >= 3 ? AppTheme.errorColor : AppTheme.primaryColor)),
        const SizedBox(width: 10),
        Expanded(child: _sensorTile(Icons.satellite_alt, 'GPS',
            data.hasLocation ? 'Locked' : 'Searching',
            data.hasLocation ? AppTheme.primaryColor : Colors.orange)),
        const SizedBox(width: 10),
        Expanded(child: _sensorTile(Icons.wifi, 'WiFi', 'Online', AppTheme.secondaryColor)),
      ],
    );
  }

  Widget _sensorTile(IconData icon, String label, String value, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildWeightChart(List<ThingSpeakBinData> history) {
    if (history.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.show_chart, size: 40, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              Text('No history yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              Text('Data will appear once the ESP32 sends readings.',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.25))),
            ],
          ),
        ),
      );
    }

    final spots = history.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weight);
    }).toList();

    final maxWeight = history.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxWeight > 0 ? maxWeight / 4 : 100,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.white.withValues(alpha: 0.05),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}g',
                    style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                color: AppTheme.primaryColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.25),
                      AppTheme.primaryColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)}g',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGPSCard(ThingSpeakBinData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GPS Location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (data.hasLocation ? AppTheme.secondaryColor : Colors.orange).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  data.hasLocation ? Icons.location_on : Icons.location_searching,
                  color: data.hasLocation ? AppTheme.secondaryColor : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: data.hasLocation
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Lat: ', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                              Text(data.latitude.toStringAsFixed(6),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('Lng: ', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                              Text(data.longitude.toStringAsFixed(6),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Acquiring GPS fix...',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Move the bin outdoors for a better signal.',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.sensors_off, size: 56, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            const Text('No hardware data yet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Make sure your ESP32 is powered on, connected to WiFi,\nand sending data to ThingSpeak.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Fetching hardware data...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            const Text('Connection Error', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Could not reach ThingSpeak. Check your internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
