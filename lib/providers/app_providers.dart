import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/thingspeak_service.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state stream - watches for login/logout/session refresh
final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange;
});

// Current user computed from session or direct check
final currentUserProvider = Provider<User?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.value?.session?.user ?? Supabase.instance.client.auth.currentUser;
});

// Profile provider - Real-time stream for instant balance updates
final profileProvider = StreamProvider<AppUser>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(AppUser(id: '', fullName: 'Guest', email: '', role: 'customer', coins: 0));
  }

  final supabase = ref.watch(supabaseProvider);
  
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((event) {
        if (event.isNotEmpty) {
          return AppUser.fromMap(event.first);
        }
        return AppUser(
          id: user.id,
          fullName: user.userMetadata?['full_name'] ?? 'User',
          email: user.email ?? '',
          role: user.userMetadata?['role'] ?? 'customer',
          coins: 0,
        );
      });
});

// Real Smart Bins for current user (Customer)
final userBinsProvider = FutureProvider<List<SmartBin>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final response = await ref
      .read(supabaseProvider)
      .from('smart_bins')
      .select()
      .eq('owner_id', user.id);

  return (response as List).map((e) => SmartBin.fromMap(e)).toList();
});

// Filter for collectors (Area selection)
final collectorAreaFilterProvider = NotifierProvider<CollectorAreaNotifier, String?>(() {
  return CollectorAreaNotifier();
});

class CollectorAreaNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  
  void setArea(String? area) => state = area;
}

// All Bins (for Collectors)
final allBinsProvider = FutureProvider<List<SmartBin>>((ref) async {
  final response = await ref
      .read(supabaseProvider)
      .from('smart_bins')
      .select()
      .order('current_weight', ascending: false);

  return (response as List).map((e) => SmartBin.fromMap(e)).toList();
});

// Filtered bins based on area selection
final filteredBinsProvider = Provider<AsyncValue<List<SmartBin>>>((ref) {
  final allBinsAsync = ref.watch(allBinsProvider);
  final filter = ref.watch(collectorAreaFilterProvider);

  return allBinsAsync.whenData((bins) {
    if (filter == null || filter == 'All Areas') return bins;
    return bins.where((b) => b.locationName?.contains(filter) ?? false).toList();
  });
});

// Available areas extracted from bin data
final availableAreasProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(allBinsProvider).whenData((bins) {
    final areas = bins
        .map((b) => b.locationName?.split(',').last.trim() ?? 'Unknown')
        .toSet()
        .toList();
    return ['All Areas', ...areas];
  });
});

// Logic for alerted bins
final alertBinsProvider = FutureProvider<List<SmartBin>>((ref) async {
  final allBins = await ref.watch(allBinsProvider.future);
  return allBins.where((b) => b.fillPercentage >= 0.625).toList();
});

// Real Rewards from DB
final rewardsProvider = FutureProvider<List<Reward>>((ref) async {
  final response = await ref
      .read(supabaseProvider)
      .from('rewards')
      .select();

  return (response as List).map((e) => Reward.fromMap(e)).toList();
});

// Fetch all registered customers for workers to see (Real-time stream)
final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .order('full_name', ascending: true)
      .map((event) {
        return event
            .map((e) => AppUser.fromMap(e))
            .where((u) => u.role != 'collector')
            .toList();
      });
});

// Collection Requests (for manual verification - Real-time stream)
final pendingCollectionsProvider = StreamProvider<List<CollectionRequest>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  
  return supabase
      .from('collection_requests')
      .stream(primaryKey: ['id'])
      .eq('status', 'pending')
      .order('created_at', ascending: false)
      .map((event) {
        return event.map((e) => CollectionRequest.fromMap(e)).toList();
      });
});

// Optimized Sign Out 
Future<void> signOut() async {
  await Supabase.instance.client.auth.signOut();
}

// Coin Transaction Timeline for Customers
final coinTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  
  final response = await ref
      .read(supabaseProvider)
      .from('coin_transactions')
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(20);
  
  return List<Map<String, dynamic>>.from(response);
});

// Claims provider: Tracks which worker has claimed which bin for collection
final claimedBinsProvider = NotifierProvider<ClaimedBinsNotifier, Map<String, String>>(() {
  return ClaimedBinsNotifier();
});

class ClaimedBinsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void claimBin(String binId, String workerId) {
    state = {...state, binId: workerId};
  }

  void unclaimBin(String binId) {
    state = Map.from(state)..remove(binId);
  }
}

// ════════════════════════════════════════════════════════
//  ThingSpeak Live Hardware Data Providers
// ════════════════════════════════════════════════════════

/// Live hardware data from ThingSpeak (auto-refreshes every 16 seconds)
final liveHardwareProvider = StreamProvider<ThingSpeakBinData?>((ref) {
  return Stream.periodic(const Duration(seconds: 16), (tick) => tick)
      .asyncMap((tick) => ThingSpeakService.fetchLatest())
      .asBroadcastStream();
});

/// One-shot fetch of latest hardware data (for manual refresh)
final latestHardwareProvider = FutureProvider<ThingSpeakBinData?>((ref) async {
  return await ThingSpeakService.fetchLatest();
});

/// Historical data from ThingSpeak (last 50 entries for charts)
final hardwareHistoryProvider = FutureProvider<List<ThingSpeakBinData>>((ref) async {
  return await ThingSpeakService.fetchHistory(results: 50);
});

// ════════════════════════════════════════════════════════
//  LEADERBOARD — All users ranked by coins (scalable)
// ════════════════════════════════════════════════════════

final leaderboardProvider = FutureProvider<List<AppUser>>((ref) async {
  final supabase = ref.read(supabaseProvider);

  final response = await supabase
      .from('profiles')
      .select()
      .eq('role', 'customer')
      .order('coins', ascending: false)
      .limit(50);

  return (response as List).map((e) => AppUser.fromMap(e)).toList();
});

