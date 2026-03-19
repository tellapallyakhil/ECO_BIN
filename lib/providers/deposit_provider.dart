import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  double get depositedWeight => (endWeight != null) ? (endWeight! - startWeight).clamp(0.0, 100.0) : 0.0;
  int get earnedCoins => (depositedWeight * 10).toInt(); // 10 coins per kg
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

  /// Finish the deposit: create a request for worker to verify
  Future<void> finishDeposit(double newWeight) async {
    if (state == null) return;

    final session = DepositSession(
      binId: state!.binId,
      startWeight: state!.startWeight,
      endWeight: newWeight,
      isActive: false,
    );

    final deposited = session.depositedWeight;

    // Create a collection request for the worker to verify
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && deposited > 0.1) { // Only if some plastic was added
      try {
        // Fetch bin location for context
        final binResponse = await Supabase.instance.client
            .from('smart_bins')
            .select('location_name')
            .eq('id', session.binId)
            .maybeSingle();

        await Supabase.instance.client.from('collection_requests').insert({
          'user_id': user.id,
          'user_name': user.userMetadata?['full_name'] ?? 'Guest User',
          'bin_id': session.binId,
          'bin_location': binResponse?['location_name'] ?? 'Bin #${session.binId}',
          'weight': deposited,
          'status': 'pending',
        });
      } catch (_) {}
    }

    state = session;
  }

  /// Reset the session
  void reset() => state = null;
}

final depositProvider = NotifierProvider<DepositNotifier, DepositSession?>(() {
  return DepositNotifier();
});
