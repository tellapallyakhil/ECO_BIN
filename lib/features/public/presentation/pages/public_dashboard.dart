import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../providers/app_providers.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/signup_page.dart';
import '../../../deposit/presentation/pages/deposit_screen.dart';
import 'qr_scanner_screen.dart';

class PublicDashboard extends ConsumerWidget {
  const PublicDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For local testing, we use a custom scheme that scanners can recognize as an app trigger
    const String appDownloadUrl = 'ecobin://join?binId=BIN-TEST-101'; 
    final binsAsync = ref.watch(allBinsProvider);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen())),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Bin to Earn', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF0D2137),
              Color(0xFF0A1628),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                
                // Now showing the official "Scan to Download" QR
                _buildDownloadQRSection(appDownloadUrl),
                const SizedBox(height: 28),

                _buildHowItWorks(),
                const SizedBox(height: 28),

                _buildLiveBinStats(binsAsync),
                const SizedBox(height: 28),

                _buildAuthActions(context),
                const SizedBox(height: 80), // Extra space for FAB
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.3),
                AppTheme.primaryColor.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: const Icon(Icons.recycling, size: 48, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        const Text(
          'EcoBin',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          'Smart Plastic Waste Management',
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildDownloadQRSection(String downloadUrl) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.system_update_alt, color: AppTheme.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join the Movement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Scan to Download & Earn Coins', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // REAL SCANNABLE QR CODE
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: downloadUrl,
              version: QrVersions.auto,
              size: 200.0,
              foregroundColor: Colors.black,
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Scan with your phone camera!',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Get the app first → then tap the "Scan Bin" button below.',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Simple Steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _stepCard('1', 'Get the App', 'Scan the QR code above with your camera.', Icons.get_app, AppTheme.primaryColor),
        const SizedBox(height: 10),
        _stepCard('2', 'Scan Pin QR', 'Open the app and scan the bin\'s sensor QR.', Icons.qr_code_scanner, AppTheme.accentColor),
        const SizedBox(height: 10),
        _stepCard('3', 'Drop Plastic', 'Place your plastic waste inside the smart bin.', Icons.scale, AppTheme.secondaryColor),
        const SizedBox(height: 10),
        _stepCard('4', 'Receive Coins', 'Coins are awarded based on weight measured.', Icons.monetization_on, Colors.amber),
      ],
    );
  }

  Widget _stepCard(String num, String title, String desc, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(num, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
          ),
          Icon(icon, color: color, size: 22),
        ],
      ),
    );
  }

  Widget _buildLiveBinStats(AsyncValue<List> binsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Bin Live Health', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 6),
            const Text('ACTIVE', style: TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        binsAsync.when(
          data: (bins) {
            final totalBins = bins.length;
            final fullBins = bins.where((b) => b.fillPercentage >= 0.85).length;
            final totalWeight = bins.fold<double>(0.0, (sum, b) => sum + b.currentWeight);

            return Row(
              children: [
                Expanded(child: _statCard('Online', '$totalBins', Icons.wifi, AppTheme.primaryColor)),
                const SizedBox(width: 10),
                Expanded(child: _statCard('Thresholds', '$fullBins', Icons.notification_important, fullBins > 0 ? AppTheme.errorColor : AppTheme.primaryColor)),
                const SizedBox(width: 10),
                Expanded(child: _statCard('Impact', '${totalWeight.toStringAsFixed(0)} kg', Icons.public, AppTheme.accentColor)),
              ],
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildAuthActions(BuildContext context) {
    return Column(
      children: [
        const Text('Admin & Existing Users', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.primaryColor)),
                ),
                child: const Text('Register', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
