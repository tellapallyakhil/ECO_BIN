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

  /// Finish the deposit: record the new weight after plastic is dropped
  Future<int> finishDeposit(double newWeight) async {
    if (state == null) return 0;

    final session = DepositSession(
      binId: state!.binId,
      startWeight: state!.startWeight,
      endWeight: newWeight,
      isActive: false,
    );

    final coins = session.earnedCoins;

    // Award coins to the current user in Supabase
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && coins > 0) {
      try {
        // Update user coins
        await Supabase.instance.client
            .from('profiles')
            .update({'coins': coins})
            .eq('id', user.id);

        // Log the transaction
        await Supabase.instance.client.from('coin_transactions').insert({
          'user_id': user.id,
          'amount': coins,
          'type': 'reward',
          'description': 'Deposited ${session.depositedWeight.toStringAsFixed(1)} kg of plastic',
        });
      } catch (_) {}
    }

    state = session;
    return coins;
  }

  /// Reset the session
  void reset() => state = null;
}

final depositProvider = NotifierProvider<DepositNotifier, DepositSession?>(() {
  return DepositNotifier();
});
