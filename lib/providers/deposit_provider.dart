import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

/// Tracks a plastic deposit session
class DepositSession {
  final String binId;
  final double startWeight;  // in grams (from hardware sensor)
  final double? endWeight;   // in grams (from hardware sensor)
  final bool isActive;

  DepositSession({
    required this.binId,
    required this.startWeight,
    this.endWeight,
    this.isActive = true,
  });

  /// How many grams were deposited (difference between end and start)
  double get depositedWeight => (endWeight != null) ? (endWeight! - startWeight).clamp(0.0, 500.0) : 0.0;
  
  /// Estimated coins based on grams deposited
  int get earnedCoins => AppConstants.calculateCoins(depositedWeight);
}

/// Manages deposit session state
class DepositNotifier extends Notifier<DepositSession?> {
  @override
  DepositSession? build() => null;

  /// Start a deposit: record the bin's current weight (in grams from hardware)
  void startDeposit(String binId, double currentWeightGrams) {
    state = DepositSession(
      binId: binId,
      startWeight: currentWeightGrams,
    );
  }

  /// Finish the deposit: record final weight and create a verification request
  Future<void> finishDeposit(double newWeightGrams) async {
    if (state == null) return;

    final deposited = (newWeightGrams - state!.startWeight).clamp(0.0, 500.0);
    
    final session = DepositSession(
      binId: state!.binId,
      startWeight: state!.startWeight,
      endWeight: newWeightGrams,
      isActive: false,
    );

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user != null && deposited > 0.5) { // At least 0.5g to count
      try {
        final binId = state!.binId;
        
        // 1. Fetch bin info for context
        final binResponse = await supabase
            .from('smart_bins')
            .select('location_name')
            .eq('id', binId)
            .maybeSingle();

        // 2. Insert into collection_requests (for worker approval)
        await supabase.from('collection_requests').insert({
          'user_id': user.id,
          'user_name': user.userMetadata?['full_name'] ?? 'Guest User',
          'bin_id': binId,
          'bin_location': binResponse?['location_name'] ?? 'Bin #$binId',
          'weight': deposited, // Weight in grams
          'status': 'pending',
        });

        // 3. Log into historical audit table for analytics
        try {
          await supabase.from('deposit_history').insert({
            'user_id': user.id,
            'bin_id': binId,
            'weight_grams': deposited.toInt(),
            'start_weight': state!.startWeight,
            'end_weight': newWeightGrams,
          });
        } catch (_) {
          // Table may not exist yet — silent fail is OK
        }

      } catch (e) {
        // Log error and handle fail
      }
    }

    state = session;
  }

  /// Reset the session
  void reset() => state = null;
}

final depositProvider = NotifierProvider<DepositNotifier, DepositSession?>(() {
  return DepositNotifier();
});
