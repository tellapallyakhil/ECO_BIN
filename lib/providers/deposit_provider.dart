import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

/// Tracks a plastic deposit session
class DepositSession {
  final String binId;
  final double startWeight;
  final double? endWeight;
  final bool isActive;

  DepositSession({
    required this.binId,
    required this.startWeight,
    this.endWeight,
    this.isActive = true,
  });

  double get depositedWeight => (endWeight != null) ? (endWeight! - startWeight).clamp(0.0, 500.0) : 0.0;
  int get earnedCoins => AppConstants.calculateCoins(depositedWeight); // 0.5 coins per gram
}

/// Manages deposit session state
class DepositNotifier extends Notifier<DepositSession?> {
  @override
  DepositSession? build() => null;

  /// Start a deposit: record the bin's current weight
  void startDeposit(String binId, double currentWeight) {
    state = DepositSession(
      binId: binId,
      startWeight: currentWeight,
    );
  }

  /// Finish the deposit: create a record and notify workers
  Future<void> finishDeposit(double newWeight) async {
    if (state == null) return;

    final deposited = (newWeight - state!.startWeight).clamp(0.0, 100.0);
    
    final session = DepositSession(
      binId: state!.binId,
      startWeight: state!.startWeight,
      endWeight: newWeight,
      isActive: false,
    );

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user != null && deposited > 0.001) { // Precision check for small deposits
      try {
        final binId = state!.binId;
        
        // 1. Fetch bin info for context
        final binResponse = await supabase
            .from('smart_bins')
            .select('location_name')
            .eq('id', binId)
            .maybeSingle();

        // 2. Insert into collection_requests (for worker approval/audit)
        await supabase.from('collection_requests').insert({
          'user_id': user.id,
          'user_name': user.userMetadata?['full_name'] ?? 'Guest User',
          'bin_id': binId,
          'bin_location': binResponse?['location_name'] ?? 'Bin #$binId',
          'weight': deposited, // Recorded in grams (hardware scale unit)
          'status': 'pending',
        });

        // 3. Log into historical audit table for analytics
        try {
          await supabase.from('deposit_history').insert({
            'user_id': user.id,
            'bin_id': binId,
            'weight_grams': (deposited * 1000).toInt(),
            'start_weight': state!.startWeight,
            'end_weight': newWeight,
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
