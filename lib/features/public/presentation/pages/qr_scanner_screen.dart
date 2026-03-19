import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/app_theme.dart';
import '../../../deposit/presentation/pages/deposit_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan Bin QR'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Color
          Container(color: Colors.black),
          
          // Camera Scanner
          MobileScanner(
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  setState(() => _isScanned = true);
                  _handleScannedCode(code);
                  break;
                }
              }
            },
          ),
          
          // Scanner Overlay (Focus Area)
          _buildScannerOverlay(),
          
          // Bottom Info
          _buildInfoPanel(),
        ],
      ),
    );
  }

  void _handleScannedCode(String code) {
    // If the QR code is our bin ID (or a URL containing it)
    // For now we accept any code that looks like a Bin ID
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DepositScreen(binId: code)),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryColor, width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Centering Bin QR Code in the frame',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      bottom: 60, left: 24, right: 24,
      child: Column(
        children: [
          const Icon(Icons.lightbulb_outline, color: AppTheme.accentColor, size: 32),
          const SizedBox(height: 16),
          const Text('Scan the QR code on the physical EcoBin to start your 2-minute deposit session.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
