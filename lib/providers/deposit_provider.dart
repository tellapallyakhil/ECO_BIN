import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

/// Tracks a plastic deposit session
class DepositSession {
  final String binId;
  final double startWeight;  // in grams (from hardware sensor)
  final double? endWeight;   // in grams (from hardware sensor)
  final bool isActive;
  final String? errorMessage; // To surface errors to UI

  DepositSession({
    required this.binId,
    required this.startWeight,
    this.endWeight,
    this.isActive = true,
    this.errorMessage,
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

  /// Finish the deposit: ALWAYS create a verification request for the worker
  Future<String?> finishDeposit(double newWeightGrams) async {
    if (state == null) return 'No active session';

    final deposited = (newWeightGrams - state!.startWeight).clamp(0.0, 500.0);
    
    final session = DepositSession(
      binId: state!.binId,
      startWeight: state!.startWeight,
      endWeight: newWeightGrams,
      isActive: false,
    );

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user == null) {
      state = session;
      return 'User not logged in';
    }

    try {
      final binId = state!.binId;
      
      // 1. Fetch user's display name from profiles table (most reliable source)
      String userName = 'Guest User';
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        userName = profileResponse?['full_name'] ?? 
                   user.userMetadata?['full_name'] ?? 
                   user.email?.split('@').first ?? 
                   'Guest User';
      } catch (_) {
        userName = user.userMetadata?['full_name'] ?? 
                   user.email?.split('@').first ?? 
                   'Guest User';
      }
      
      // 2. Fetch bin info for context
      String binLocation = 'Bin #$binId';
      try {
        final binResponse = await supabase
            .from('smart_bins')
            .select('location_name')
            .eq('id', binId)
            .maybeSingle();
        binLocation = binResponse?['location_name'] ?? binLocation;
      } catch (_) {}

      // 3. ALWAYS insert into collection_requests — worker will see it
      //    Even if weight is 0, still record so worker knows someone used the bin
      await supabase.from('collection_requests').insert({
        'user_id': user.id,
        'user_name': userName,
        'bin_id': binId,
        'bin_location': binLocation,
        'weight': deposited, // Weight in grams (difference)
        'status': 'pending',
      });

      debugPrint('✅ Collection request created: $userName deposited ${deposited}g at $binLocation');

      // 4. Log into historical audit table for analytics (optional table)
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

      state = session;
      return null; // success

    } catch (e) {
      debugPrint('❌ Failed to create collection request: $e');
      state = session.copyWithError('Failed to record deposit: $e');
      return e.toString();
    }
  }

  /// Reset the session
  void reset() => state = null;
}

/// Extension to allow copying session with an error message
extension _DepositSessionCopy on DepositSession {
  DepositSession copyWithError(String error) {
    return DepositSession(
      binId: binId,
      startWeight: startWeight,
      endWeight: endWeight,
      isActive: isActive,
      errorMessage: error,
    );
  }
}

final depositProvider = NotifierProvider<DepositNotifier, DepositSession?>(() {
  return DepositNotifier();
});
