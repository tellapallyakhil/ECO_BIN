import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state stream
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

// Current user session
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? ref.watch(supabaseProvider).auth.currentUser;
});

// Profile provider - Pure Supabase fetch
final profileProvider = FutureProvider<AppUser>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw Exception('Not authenticated');

  final supabase = ref.watch(supabaseProvider);
  
  final response = await supabase
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (response != null) {
    return AppUser.fromMap(response);
  }

  // If no profile exists, we attempt to use meta-data as a fallback
  return AppUser(
    id: user.id,
    fullName: user.userMetadata?['full_name'] ?? 'User',
    email: user.email ?? '',
    role: user.userMetadata?['role'] ?? 'customer',
    coins: 0,
  );
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
  return allBins.where((b) => b.fillPercentage >= 0.85).toList();
});

// Real Rewards from DB
final rewardsProvider = FutureProvider<List<Reward>>((ref) async {
  final response = await ref
      .read(supabaseProvider)
      .from('rewards')
      .select();

  return (response as List).map((e) => Reward.fromMap(e)).toList();
});

// Collection Requests (for manual verification)
final pendingCollectionsProvider = FutureProvider<List<CollectionRequest>>((ref) async {
  final response = await ref
      .read(supabaseProvider)
      .from('collection_requests')
      .select()
      .eq('status', 'pending')
      .order('created_at', ascending: false);

  return (response as List).map((e) => CollectionRequest.fromMap(e)).toList();
});

// Optimized Sign Out 
Future<void> signOut() async {
  await Supabase.instance.client.auth.signOut();
}
