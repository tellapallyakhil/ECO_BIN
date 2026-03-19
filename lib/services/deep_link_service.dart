import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/deposit/presentation/pages/deposit_screen.dart';

/// Service to handle Deep Links (Universal Links / App Links)
class DeepLinkService {
  final WidgetRef ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  DeepLinkService(this.ref);

  void init(BuildContext context) {
    // 1. Handle deep link when the app is already open
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(context, uri);
    });

    // 2. Handle deep link when the app is launched from cold start
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleUri(context, uri);
      }
    });
  }

  void _handleUri(BuildContext context, Uri uri) {
    // Check both web URLs (https://ecobin.app/join) and APP SCHEMES (ecobin://join)
    if (uri.path.contains('/join') || uri.host.contains('join')) {
      final binId = uri.queryParameters['binId'];
      if (binId != null && binId.isNotEmpty) {
        _navigateToDeposit(context, binId);
      }
    }
  }

  void _navigateToDeposit(BuildContext context, String binId) {
    // Smoothly transition to the deposit screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DepositScreen(binId: binId),
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}

// Provider for the service
final deepLinkServiceProvider = Provider.family<DeepLinkService, WidgetRef>((ref, widgetRef) {
  return DeepLinkService(widgetRef);
});
