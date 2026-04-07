import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;

class LocationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Determine the current position of the device.
  /// When the location services are not enabled or permissions are denied
  /// the `Future` will return an error.
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      dev.log('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        dev.log('Location permissions are denied');
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      dev.log('Location permissions are permanently denied, we cannot request permissions.');
      return null;
    } 

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      dev.log('Error getting current position: $e');
      return null;
    }
  }

  /// Updates the location of the bin(s) owned by the current user
  /// to match the device's current location.
  static Future<void> syncBinLocationWithUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final position = await getCurrentPosition();
    if (position == null) return;

    dev.log('Syncing bin location with user location: ${position.latitude}, ${position.longitude}');

    try {
      // Update all bins owned by this user
      await _supabase
          .from('smart_bins')
          .update({
            'location_lat': position.latitude,
            'location_lng': position.longitude,
            'location_name': 'Physical Bin (User Located)',
          })
          .eq('owner_id', user.id);
      
      dev.log('Bin location updated successfully in Supabase.');
    } catch (e) {
      dev.log('Failed to update bin location: $e');
    }
  }
}
