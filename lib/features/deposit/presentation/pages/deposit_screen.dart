import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../providers/deposit_provider.dart';
import '../../../../providers/app_providers.dart';
import '../../../../services/thingspeak_service.dart';

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

  // Weight tracking (in grams, from hardware)
  double _startWeightGrams = 0.0;
  double _currentLiveWeightGrams = 0.0;
  double _endWeightGrams = 0.0;
  Timer? _liveWeightTimer;

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
    _liveWeightTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startDeposit() async {
    // Fetch live weight from ThingSpeak hardware FIRST
    try {
      final liveData = await ThingSpeakService.fetchLatest();
      if (liveData != null) {
        _startWeightGrams = liveData.weight;
        _currentLiveWeightGrams = liveData.weight;
      }
    } catch (_) {}

    // Record in provider (for Supabase logging)
    ref.read(depositProvider.notifier).startDeposit(widget.binId, _startWeightGrams);

    if (mounted) {
      setState(() => _step = 1);
      _startCountdown();
      _startLiveWeightPolling();
    }
  }

  /// Poll ThingSpeak every 5 seconds to show live weight during the countdown
  void _startLiveWeightPolling() {
    _liveWeightTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || _step != 1) {
        timer.cancel();
        return;
      }
      try {
        final liveData = await ThingSpeakService.fetchLatest();
        if (liveData != null && mounted) {
          setState(() {
            _currentLiveWeightGrams = liveData.weight;
          });
        }
      } catch (_) {}
    });
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
    _liveWeightTimer?.cancel();

    // Fetch final weight from hardware
    try {
      final liveData = await ThingSpeakService.fetchLatest();
      if (liveData != null) {
        _endWeightGrams = liveData.weight;
      } else {
        _endWeightGrams = _currentLiveWeightGrams;
      }
    } catch (_) {
      _endWeightGrams = _currentLiveWeightGrams;
    }

    setState(() => _step = 2);

    // Log the deposit via provider (for Supabase)
    try {
      await ref.read(depositProvider.notifier).finishDeposit(_endWeightGrams);

      // Refresh all data so home shows updated info
      ref.invalidate(userBinsProvider);
      ref.invalidate(allBinsProvider);
      ref.invalidate(coinTransactionsProvider);
      ref.invalidate(pendingCollectionsProvider);
    } catch (_) {}
  }

  /// Weight deposited in grams
  double get _depositedGrams => (_endWeightGrams - _startWeightGrams).clamp(0.0, 500.0);

  /// Live weight added so far during countdown (in grams)
  double get _liveAddedGrams => (_currentLiveWeightGrams - _startWeightGrams).clamp(0.0, 500.0);

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
                        _liveWeightTimer?.cancel();
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
        _stepDot(2, 'Result'),
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
          const SizedBox(height: 8),
          Text('Reading current weight from sensor', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
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
            const SizedBox(height: 28),

            // ────────────────────────────────────────────────
            // LIVE WEIGHT PANEL — shows bin weight in real time
            // ────────────────────────────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Start weight
                      Column(
                        children: [
                          Icon(Icons.scale_outlined, size: 18, color: Colors.white.withValues(alpha: 0.4)),
                          const SizedBox(height: 6),
                          Text('${_startWeightGrams.toStringAsFixed(1)}g',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Before', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                        ],
                      ),
                      // Arrow
                      Icon(Icons.arrow_forward, color: AppTheme.accentColor.withValues(alpha: 0.6)),
                      // Current live weight
                      Column(
                        children: [
                          const Icon(Icons.monitor_weight, size: 18, color: AppTheme.accentColor),
                          const SizedBox(height: 6),
                          Text('${_currentLiveWeightGrams.toStringAsFixed(1)}g',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentColor)),
                          const SizedBox(height: 2),
                          Text('Live Now', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                        ],
                      ),
                      // Arrow
                      Icon(Icons.arrow_forward, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
                      // Difference so far
                      Column(
                        children: [
                          const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(height: 6),
                          Text('+${_liveAddedGrams.toStringAsFixed(1)}g',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          const SizedBox(height: 2),
                          Text('Added', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Live Action Guidance
            Text('Drop Your Plastic Now!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9))),
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
                      'The sensor is tracking your deposit live. Drop all plastic items before the timer ends.',
                      style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

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
    final depositedGrams = _depositedGrams;
    final estimatedCoins = AppConstants.calculateCoins(depositedGrams);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success check icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.25),
                    AppTheme.accentColor.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: Icon(
                depositedGrams > 0.5 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 56,
                color: depositedGrams > 0.5 ? AppTheme.primaryColor : Colors.orange,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              depositedGrams > 0.5 ? 'Deposit Recorded! ✅' : 'No Waste Detected',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // ────────────────────────────────────────────────
            // WEIGHT BREAKDOWN CARD
            // ────────────────────────────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Weight before & after
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _weightStat('Before', '${_startWeightGrams.toStringAsFixed(1)}g', Colors.grey),
                      Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
                      _weightStat('After', '${_endWeightGrams.toStringAsFixed(1)}g', Colors.grey),
                      Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
                      _weightStat('You Threw', '${depositedGrams.toStringAsFixed(1)}g', AppTheme.accentColor),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Divider
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 20),
                  // The big highlighted message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.recycling, color: AppTheme.primaryColor, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                depositedGrams > 0.5
                                    ? 'You threw ${depositedGrams.toStringAsFixed(1)} grams of waste!'
                                    : 'No significant waste was detected.',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                depositedGrams > 0.5
                                    ? '≈ ${(depositedGrams / 1000).toStringAsFixed(3)} kg deposited'
                                    : 'Try again with some plastic waste.',
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ────────────────────────────────────────────────
            // COINS FORWARDING MESSAGE
            // ────────────────────────────────────────────────
            if (depositedGrams > 0.5) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
                child: Column(
                  children: [
                    const Icon(Icons.monetization_on, color: AppTheme.accentColor, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      '~$estimatedCoins EcoCoins',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'According to your waste, we will be forwarding the EcoCoins to your account once verified by a worker.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${AppConstants.coinsPerGram} coin per gram • Worker verification required',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            SizedBox(
              width: 220, height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(depositProvider.notifier).reset();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.home, size: 18),
                label: const Text('Return to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
      ],
    );
  }
}
