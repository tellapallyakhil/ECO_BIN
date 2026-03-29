import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../providers/deposit_provider.dart';
import '../../../../providers/app_providers.dart';

class DepositScreen extends ConsumerStatefulWidget {
  final String binId;
  const DepositScreen({super.key, required this.binId});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> with SingleTickerProviderStateMixin {
  int _step = 0; // 0 = connecting, 1 = countdown, 2 = done
  int _secondsLeft = 120; // 2 minutes
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startDeposit();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startDeposit() async {
    try {
      final bins = await ref.read(allBinsProvider.future);
      final bin = bins.firstWhere((b) => b.id == widget.binId, orElse: () => bins.first);
      ref.read(depositProvider.notifier).startDeposit(widget.binId, bin.currentWeight);
    } catch (_) {
      ref.read(depositProvider.notifier).startDeposit(widget.binId, 0.0);
    }
    setState(() => _step = 1);
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _finishDeposit();
      }
    });
  }

  void _finishDeposit() async {
    _timer?.cancel();
    setState(() => _step = 2);

    try {
      ref.invalidate(allBinsProvider);
      final bins = await ref.read(allBinsProvider.future);
      final bin = bins.firstWhere((b) => b.id == widget.binId, orElse: () => bins.first);
      await ref.read(depositProvider.notifier).finishDeposit(bin.currentWeight);
    } catch (_) {}
  }

  String get _timerText {
    final min = _secondsLeft ~/ 60;
    final sec = _secondsLeft % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  double get _progress => _secondsLeft / 120.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1628), Color(0xFF0D2137), Color(0xFF0A1628)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        _timer?.cancel();
                        ref.read(depositProvider.notifier).reset();
                        Navigator.pop(context);
                      },
                    ),
                    const Expanded(
                      child: Text('Plastic Deposit', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 32),

                // Step indicator
                _buildStepIndicator(),
                const SizedBox(height: 40),

                // Main content
                Expanded(child: _buildStepContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(0, 'Scan'),
        _stepLine(0),
        _stepDot(1, 'Drop'),
        _stepLine(1),
        _stepDot(2, 'Earn'),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _step >= step;
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: isActive ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('${step + 1}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _stepLine(int step) {
    final isActive = _step > step;
    return Container(
      width: 60, height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildConnectingState();
      case 1:
        return _buildCountdownState();
      case 2:
        return _buildDoneState();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildConnectingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 20),
          Text('Connecting to bin...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildCountdownState() {
    final isUrgent = _secondsLeft <= 30;
    final timerColor = isUrgent ? AppTheme.errorColor : AppTheme.primaryColor;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Countdown Timer Ring
            SizedBox(
              width: 200, height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background ring
                  SizedBox(
                    width: 200, height: 200,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 8,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  // Progress ring
                  SizedBox(
                    width: 220, height: 220,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 10,
                      color: timerColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  // Timer text and central content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timerText,
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: timerColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'WINDOW OPEN',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: timerColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Live Action Guidance
            Text('Ready, Set, Drop!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.accentColor, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'The bin is currently tracking your deposit. Please drop all plastic items now.',
                      style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Animated bin icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -(_pulseController.value * 12)),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.recycling, size: 48, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 48),

            // Early finish button
            SizedBox(
              width: 180,
              child: OutlinedButton.icon(
                onPressed: _finishDeposit,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Finish Early'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.6),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneState() {
    final session = ref.watch(depositProvider);
    final deposited = session?.depositedWeight ?? 0.0;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pending Verification icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.2),
                    AppTheme.accentColor.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: const Icon(Icons.hourglass_top, size: 56, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text('Deposit Recorded! 📝', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'You dropped ${deposited.toStringAsFixed(1)} kg of waste.',
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 32),

            // Pending message card
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Column(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppTheme.primaryColor, size: 32),
                  const SizedBox(height: 16),
                  const Text(
                    'Manual Verification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A worker will verify your deposit at this bin soon. Coins will be manually assigned once verified.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: 200, height: 48,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(depositProvider.notifier).reset();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Return to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
