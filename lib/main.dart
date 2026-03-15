import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'providers/app_providers.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/home/presentation/pages/customer_home.dart';
import 'features/home/presentation/pages/collector_home.dart';

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

class EcoBinApp extends StatelessWidget {
  const EcoBinApp({super.key});

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
    // Check if there's a current session
    final session = ref.watch(supabaseProvider).auth.currentSession;
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        if (state.session != null || session != null) {
          return const _RoleRouter();
        }
        return const LoginPage();
      },
      loading: () {
        // While loading, check if there's an existing session
        if (session != null) {
          return const _RoleRouter();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (e, _) => const LoginPage(),
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
        // On error, default to customer home
        return const CustomerHome();
      },
    );
  }
}
