import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'providers/app_providers.dart';
import 'features/public/presentation/pages/public_dashboard.dart';
import 'features/home/presentation/pages/customer_home.dart';
import 'features/home/presentation/pages/collector_home.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: EcoBinApp(),
    ),
  );
}

class EcoBinApp extends ConsumerStatefulWidget {
  const EcoBinApp({super.key});

  @override
  ConsumerState<EcoBinApp> createState() => _EcoBinAppState();
}

class _EcoBinAppState extends ConsumerState<EcoBinApp> {
  late DeepLinkService _deepLinkService;

  @override
  void initState() {
    super.initState();
    _deepLinkService = DeepLinkService(ref);
    // Wrap in a post-frame callback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkService.init(context);
    });
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

/// AuthGate listens to Supabase auth state and routes accordingly.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        // If logged in, route to appropriate dashboard
        if (state.session != null) {
          return const _RoleRouter();
        }
        // If NOT logged in, show the Public Landing Dashboard
        return const PublicDashboard();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const PublicDashboard(), // Fallback to public on error
    );
  }
}

/// Routes to the correct home page based on user role.
class _RoleRouter extends ConsumerWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        // Guard: If profile belongs to a different ID, we are in a transition state
        if (user != null && profile.id.isNotEmpty && profile.id != user.id) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (profile.isCollector) {
          return const CollectorHome();
        }
        return const CustomerHome();
      },
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text('Loading dashboard...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ),
      error: (e, _) {
        return const CustomerHome();
      },
    );
  }
}
