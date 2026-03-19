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
  int _earnedCoins = 0;
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
      final coins = await ref.read(depositProvider.notifier).finishDeposit(bin.currentWeight);
      if (mounted) setState(() => _earnedCoins = coins);
    } catch (_) {
      if (mounted) setState(() => _earnedCoins = 0);
    }
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
                    width: 200, height: 200,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 8,
                      color: timerColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  // Timer text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timerText,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('remaining', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Animated bin icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) => Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.08),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.delete_outline, size: 40, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Drop your plastic now!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Place your plastic waste inside the bin.\nCoins will be calculated when the timer ends.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), height: 1.5),
            ),
            const SizedBox(height: 32),

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
            // Success icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.2),
                    AppTheme.accentColor.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: const Icon(Icons.celebration, size: 56, color: AppTheme.accentColor),
            ),
            const SizedBox(height: 24),
            const Text('Thank You! 🎉', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'You deposited ${deposited.toStringAsFixed(1)} kg of plastic!',
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),

            // Coins earned card
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Column(
                children: [
                  const Icon(Icons.monetization_on, color: AppTheme.accentColor, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    '+$_earnedCoins',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                  ),
                  const SizedBox(height: 4),
                  const Text('EcoCoins Earned', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '10 coins per kg of plastic deposited',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 32),

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
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
