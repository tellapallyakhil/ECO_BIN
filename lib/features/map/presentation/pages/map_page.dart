import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../services/location_service.dart';
import '../../../../models/models.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController _mapController = MapController();
  LatLng _selectedLocation = const LatLng(17.3850, 78.4867);
  bool _isSelectionMode = false;
  String _locationName = "Manually Selected Location";

  @override
  Widget build(BuildContext context) {
    final binsAsync = ref.watch(allBinsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? 'Select Location' : 'Bin Locations'),
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.add_location_alt, color: AppTheme.accentColor),
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allBinsProvider),
          ),
        ],
      ),
      body: binsAsync.when(
        data: (bins) => _buildMap(context, bins),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            mini: true,
            onPressed: _centerOnUser,
            backgroundColor: AppTheme.surfaceColor,
            child: const Icon(Icons.my_location, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          if (_isSelectionMode)
            FloatingActionButton.extended(
              onPressed: _saveNewLocation,
              label: const Text('Confirm Location'),
              icon: const Icon(Icons.check),
              backgroundColor: AppTheme.primaryColor,
            ),
        ],
      ),
    );
  }

  Future<void> _centerOnUser() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      if (_isSelectionMode) {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
      }
    }
  }


  Future<void> _saveNewLocation() async {
    // Logic to save the selected location to Supabase
    final supabase = ref.read(supabaseProvider);
    final user = ref.read(currentUserProvider);

    if (user == null) return;

    try {
      await supabase.from('smart_bins').insert({
        'owner_id': user.id,
        'location_lat': _selectedLocation.latitude,
        'location_lng': _selectedLocation.longitude,
        'location_name': _locationName,
        'current_weight': 0.0,
        'threshold': AppConstants.defaultThresholdKg,
      });

      if (mounted) {
        setState(() => _isSelectionMode = false);
        ref.invalidate(allBinsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ New bin location added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error saving location: $e')),
        );
      }
    }
  }

  Widget _buildMap(BuildContext context, List<SmartBin> bins) {
    // Default to a central location (e.g., center of your city or 0,0)
    LatLng center = const LatLng(17.3850, 78.4867); 
    
    if (bins.isNotEmpty) {
      center = LatLng(bins.first.latitude, bins.first.longitude);
    }

    if (bins.isEmpty) {
      return Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isSelectionMode) {
                  _selectedLocation = position.center!;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.eco.bin.eco_bin',
              ),
              if (_isSelectionMode)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 35),
                    child: Icon(Icons.location_on, color: AppTheme.errorColor, size: 40),
                  ),
                ),
            ],
          ),
          Center(
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  const Text('No bin locations found', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Active hardware will appear here.', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final markers = bins.map<Marker>((bin) {
      final pct = bin.fillPercentage;
      final color = pct >= 0.625
          ? AppTheme.errorColor
          : (pct >= 0.4 ? AppTheme.accentColor : AppTheme.primaryColor);

      return Marker(
        point: LatLng(bin.latitude, bin.longitude),
        width: 70,
        height: 70,
        child: GestureDetector(
          onTap: () => _showBinDetails(context, bin),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
                ),
                child: Text(
                  '${bin.currentWeight}kg',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 2),
              Icon(Icons.location_on, color: color, size: 32),
            ],
          ),
        ),
      );
    }).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && _isSelectionMode) {
                _selectedLocation = position.center!;
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.eco.bin.eco_bin',
            ),
            MarkerLayer(markers: markers),
            if (_isSelectionMode)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 35),
                  child: Icon(Icons.location_on, color: AppTheme.errorColor, size: 40),
                ),
              ),
          ],
        ),
        // Legend
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: GlassCard(
            blur: 15,
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendItem(AppTheme.primaryColor, 'OK (<60%)'),
                _legendItem(AppTheme.accentColor, 'Filling (60-85%)'),
                _legendItem(AppTheme.errorColor, 'Full (>85%)'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
      ],
    );
  }

  void _showBinDetails(BuildContext context, SmartBin bin) {
    final pct = bin.fillPercentage;
    final color = pct >= 0.625
        ? AppTheme.errorColor
        : (pct >= 0.4 ? AppTheme.accentColor : AppTheme.primaryColor);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bin.locationName ?? 'Smart Bin', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Bin #${bin.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    pct >= 0.625 ? 'FULL' : 'ACTIVE',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Waste details
            Row(
              children: [
                Expanded(child: _detailTile('Current Weight', '${bin.currentWeight} kg', Icons.monitor_weight)),
                const SizedBox(width: 12),
                Expanded(child: _detailTile('Threshold', '${bin.threshold} kg', Icons.speed)),
                const SizedBox(width: 12),
                Expanded(child: _detailTile('Fill Level', '${(pct * 100).toInt()}%', Icons.pie_chart)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _detailTile('Latitude', bin.latitude.toStringAsFixed(4), Icons.explore)),
                const SizedBox(width: 12),
                Expanded(child: _detailTile('Longitude', bin.longitude.toStringAsFixed(4), Icons.explore)),
                const SizedBox(width: 12),
                Expanded(child: _detailTile('Status', bin.isFull ? 'FULL' : 'ACTIVE', Icons.info_outline)),
              ],
            ),
            const SizedBox(height: 20),
            // Fill bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pct >= 0.625
                  ? '⚠️ This bin needs immediate collection!'
                  : 'Bin is operating normally.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}
