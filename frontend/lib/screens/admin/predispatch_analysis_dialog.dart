import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';

import '../../services/api_service.dart';
import 'readiness_alerts_dialog.dart';

class PreDispatchAnalysisDialog extends StatefulWidget {
  final String cycleId;
  final String? fpsId;
  final ApiService? apiService;
  final VoidCallback? onDispatchCompleted;
  final VoidCallback? onDispatchDelayed;

  const PreDispatchAnalysisDialog({
    super.key,
    this.cycleId = '2026-09',
    this.fpsId,
    this.apiService,
    this.onDispatchCompleted,
    this.onDispatchDelayed,
  });

  static Future<void> show(
    BuildContext context, {
    String cycleId = '2026-09',
    String? fpsId,
    VoidCallback? onDispatchCompleted,
    VoidCallback? onDispatchDelayed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PreDispatchAnalysisDialog(
        cycleId: cycleId,
        fpsId: fpsId,
        onDispatchCompleted: onDispatchCompleted,
        onDispatchDelayed: onDispatchDelayed,
      ),
    );
  }

  @override
  State<PreDispatchAnalysisDialog> createState() => _PreDispatchAnalysisDialogState();
}

class _PreDispatchAnalysisDialogState extends State<PreDispatchAnalysisDialog> {
  late final ApiService _apiService;
  
  // Pipeline Stage Definition
  static const List<Map<String, String>> _stages = [
    {
      'titleKey': 'predispatch.stage_forecast',
      'titleDefault': '1. FORECAST',
      'descKey': 'predispatch.forecast_desc',
      'descDefault': 'Aggregating citizen intents & multi-factor composite demand (D̂)',
      'successValue': '62.7 MT Aggregated Demand Calculated (20 FPS)',
    },
    {
      'titleKey': 'predispatch.stage_validate',
      'titleDefault': '2. VALIDATE',
      'descKey': 'predispatch.validate_desc',
      'descDefault': 'Auditing 9 statutory floors, buffer stocks & invariant constraints',
      'successValue': '9 Invariant Rules Verified • 20/20 FPS Compliant',
      'warningValue': 'Government buffer stock currently unavailable (Deficit: 8.4 MT)',
    },
    {
      'titleKey': 'predispatch.stage_optimize',
      'titleDefault': '3. OPTIMIZE',
      'descKey': 'predispatch.optimize_desc',
      'descDefault': 'Computing multi-stop TSP corridors & dynamic fleet scheduling',
      'successValue': '4 Fleet Corridors Generated • Total 142 km (Efficiency: 96.4%)',
      'delayedValue': 'Fleet corridors scheduled for stock replenishment window',
    },
    {
      'titleKey': 'predispatch.stage_manifest',
      'titleDefault': '4. MANIFEST',
      'descKey': 'predispatch.manifest_desc',
      'descDefault': 'Sealing cryptographic SHA-256 digital gatepass & allocations',
      'successValue': 'Cryptographic SHA-256 Gatepasses Pre-Allocated & Ready',
      'delayedValue': 'Gatepasses staged pending government stock arrival (1–2 days)',
    },
  ];

  // Execution State
  bool _isRunning = false;
  bool _isCompleted = false;
  bool _simulateStockShortage = false;
  int _currentStageIndex = -1; // -1: Not started, 0..3: active stage, 4: all completed
  // ignore: unused_field
  String? _errorMessage;
  int _activeStageSeconds = 0;
  final Map<int, int> _stageDurations = {}; // stores completed seconds per stage
  Timer? _timer;
  bool _isActionExecuting = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    // Auto-start pipeline execution on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnalysisPipeline();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnalysisPipeline() {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isCompleted = false;
      _currentStageIndex = 0;
      _activeStageSeconds = 0;
      _stageDurations.clear();
      _errorMessage = null;
    });

    _startTimerForCurrentStage();
  }

  void _startTimerForCurrentStage() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _activeStageSeconds++;
      });

      // Advance stage after realistic simulated processing duration
      final targetDuration = _simulateStockShortage
          ? (_currentStageIndex == 0 ? 3 : (_currentStageIndex == 1 ? 2 : 2))
          : (_currentStageIndex == 0 ? 3 : (_currentStageIndex == 1 ? 2 : (_currentStageIndex == 2 ? 3 : 2)));

      if (_activeStageSeconds >= targetDuration) {
        _advanceToNextStage();
      }
    });
  }

  void _advanceToNextStage() {
    _stageDurations[_currentStageIndex] = _activeStageSeconds;

    // If stock shortage scenario, stop at stage 1 (Validate) with stock constraint warning
    if (_simulateStockShortage && _currentStageIndex == 1) {
      _timer?.cancel();
      // Record staged times for remaining
      _stageDurations[2] = 0;
      _stageDurations[3] = 0;
      setState(() {
        _isRunning = false;
        _isCompleted = true;
        _currentStageIndex = 4;
      });
      return;
    }

    if (_currentStageIndex < _stages.length - 1) {
      setState(() {
        _currentStageIndex++;
        _activeStageSeconds = 0;
      });
    } else {
      // Completed all stages
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _isCompleted = true;
        _currentStageIndex = 4;
      });
    }
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handleDelayDispatch() async {
    setState(() => _isActionExecuting = true);
    try {
      await _apiService.delayDispatch(
        fpsId: widget.fpsId,
        delayDays: '1–2 days',
        reason: 'Government stock currently unavailable for this dispatch.',
        cycleId: widget.cycleId,
      );

      if (!mounted) return;
      widget.onDispatchDelayed?.call();

      // Show option to open notification dispatcher
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Dispatch delayed by 1–2 days. Status: ⏳ Delayed — Stock Replenishment Pending.'),
          backgroundColor: const Color(0xFFB45309),
          action: SnackBarAction(
            label: 'Notify Citizens',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ReadinessAlertsDialog(cycleId: widget.cycleId),
              );
            },
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record delay: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  Future<void> _handleProceedNormalDispatch() async {
    setState(() => _isActionExecuting = true);
    try {
      await _apiService.runPreDispatchAnalysis(
        fpsId: widget.fpsId,
        cycleId: widget.cycleId,
        simulateStockShortage: false,
      );

      if (!mounted) return;
      widget.onDispatchCompleted?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pre-Dispatch Analysis validated! Manifest sealed and ready for fleet dispatch.'),
          backgroundColor: AppConstants.successGreen,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 960,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildScenarioSelector(),
                  const SizedBox(height: 18),
                  _buildStagePipeline(),
                  const SizedBox(height: 18),
                  if (_isCompleted) _buildOutcomeSection(),
                  const SizedBox(height: 20),
                  _buildFooterActions(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppConstants.primaryNavy.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.analytics_rounded, color: AppConstants.primaryNavy, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tr('predispatch.modal_title'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.primaryNavy,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppConstants.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppConstants.accentAmber),
                    ),
                    child: Text(
                      'CYCLE ${widget.cycleId}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Pre-Dispatch Decision Pipeline: Forecast → Validate → Optimize → Manifest (with Live Processing Timers)',
                style: TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppConstants.textSecondary),
          tooltip: tr('nav.close'),
        ),
      ],
    );
  }

  Widget _buildScenarioSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: AppConstants.primaryNavy),
              SizedBox(width: 6),
              Text(
                'DEMO SCENARIO:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.4),
              ),
            ],
          ),
          _buildScenarioChip(
            label: tr('predispatch.scenario_normal'),
            isSelected: !_simulateStockShortage,
            onTap: () {
              if (_simulateStockShortage) {
                setState(() => _simulateStockShortage = false);
                _startAnalysisPipeline();
              }
            },
            activeColor: AppConstants.successGreen,
          ),
          _buildScenarioChip(
            label: tr('predispatch.scenario_shortage'),
            isSelected: _simulateStockShortage,
            onTap: () {
              if (!_simulateStockShortage) {
                setState(() => _simulateStockShortage = true);
                _startAnalysisPipeline();
              }
            },
            activeColor: const Color(0xFFB45309),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : AppConstants.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? activeColor : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : AppConstants.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStagePipeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (_isRunning)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryNavy),
                    )
                  else
                    Icon(
                      _simulateStockShortage ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      size: 16,
                      color: _simulateStockShortage ? const Color(0xFFB45309) : AppConstants.successGreen,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isRunning
                        ? tr('predispatch.running')
                        : (_simulateStockShortage
                            ? tr('predispatch.stock_warning_title')
                            : tr('predispatch.completed_all')),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _simulateStockShortage && _isCompleted
                          ? const Color(0xFFB45309)
                          : AppConstants.primaryNavy,
                    ),
                  ),
                ],
              ),
              if (_isRunning)
                Text(
                  'ACTIVE STAGE TIMER: ${_formatTimer(_activeStageSeconds)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.accentBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 4-Stage Step-by-Step Rows
          ...List.generate(_stages.length, (index) {
            return _buildStageRow(index);
          }),
        ],
      ),
    );
  }

  Widget _buildStageRow(int index) {
    final stage = _stages[index];
    final titleKey = stage['titleKey']!;
    final descKey = stage['descKey']!;
    final translatedTitle = tr(titleKey);
    final title = translatedTitle == titleKey ? (stage['titleDefault'] ?? titleKey) : translatedTitle;
    final translatedDesc = tr(descKey);
    final desc = translatedDesc == descKey ? (stage['descDefault'] ?? descKey) : translatedDesc;

    final isCompleted = _currentStageIndex > index || (_isCompleted && (!_simulateStockShortage || index <= 1));
    final isActive = _currentStageIndex == index && _isRunning;
    final isStockShortageStage = _simulateStockShortage && index == 1 && (_isCompleted || isActive);
    final isPendingAfterShortage = _simulateStockShortage && index > 1 && _isCompleted;

    // Timer display string
    String timerText;
    if (isCompleted) {
      final sec = _stageDurations[index] ?? 0;
      timerText = _formatTimer(sec);
    } else if (isActive) {
      timerText = _formatTimer(_activeStageSeconds);
    } else {
      timerText = '--:--';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppConstants.accentBlue.withValues(alpha: 0.06)
            : (isStockShortageStage
                ? const Color(0xFFFFFBEB)
                : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppConstants.accentBlue
              : (isStockShortageStage
                  ? const Color(0xFFFDE68A)
                  : (isCompleted ? AppConstants.successGreen.withValues(alpha: 0.4) : AppConstants.cardBorder)),
          width: isActive || isStockShortageStage ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? (isStockShortageStage ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7))
                  : (isActive ? AppConstants.primaryNavy : const Color(0xFFF1F5F9)),
            ),
            child: Center(
              child: isCompleted
                  ? (isStockShortageStage
                      ? const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309))
                      : const Icon(Icons.check, size: 16, color: Color(0xFF15803D)))
                  : (isActive
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          '○',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade400,
                          ),
                        )),
            ),
          ),
          const SizedBox(width: 14),

          // Stage Title & Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isStockShortageStage
                            ? const Color(0xFFB45309)
                            : (isActive ? AppConstants.primaryNavy : AppConstants.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCompleted)
                      Text(
                        isStockShortageStage ? '⚠ CONSTRAINT DETECTED' : '✓ COMPLETED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isStockShortageStage ? const Color(0xFFB45309) : const Color(0xFF15803D),
                        ),
                      )
                    else if (isActive)
                      const Text(
                        '⟳ PROCESSING...',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppConstants.accentBlue),
                      )
                    else if (isPendingAfterShortage)
                      const Text(
                        '⏳ STAGED FOR REPLENISHMENT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isStockShortageStage
                      ? stage['warningValue']!
                      : (isCompleted ? (stage['successValue'] ?? desc) : desc),
                  style: TextStyle(
                    fontSize: 11,
                    color: isStockShortageStage ? const Color(0xFF92400E) : AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Visible Elapsed Time Timer (e.g. 00:04, 00:02)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppConstants.primaryNavy
                  : (isCompleted
                      ? (isStockShortageStage ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9))
                      : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? AppConstants.primaryNavy
                    : (isStockShortageStage ? const Color(0xFFFDE68A) : AppConstants.cardBorder),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: isActive
                      ? Colors.white
                      : (isStockShortageStage ? const Color(0xFFB45309) : AppConstants.textSecondary),
                ),
                const SizedBox(width: 4),
                Text(
                  timerText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isActive
                        ? Colors.white
                        : (isStockShortageStage ? const Color(0xFFB45309) : AppConstants.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeSection() {
    if (_simulateStockShortage) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
                SizedBox(width: 8),
                Text(
                  '⚠ Stock Constraint Detected — Operational Warning',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• Reason: Government stock currently unavailable for this dispatch.\n'
              '• Impact: Dispatch temporarily delayed (Estimated: 1–2 days).\n'
              '• Recommended Action: Delay Dispatch, Notify Beneficiaries, and Stage Replenishment Gatepass.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.45),
            ),
            const Divider(height: 16, color: Color(0xFFFDE68A)),
            Row(
              children: [
                const Icon(Icons.gavel_rounded, size: 14, color: Color(0xFFB45309)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr('predispatch.policy_notice'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF15803D), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pre-Dispatch Decision Pipeline Passed Successfully',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'All 20 Fair Price Shops verified. 4 truck corridors optimized. SHA-256 digital gatepasses ready for seal.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFooterActions() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: _isRunning ? null : _startAnalysisPipeline,
          icon: const Icon(Icons.replay_rounded, size: 16),
          label: const Text('Re-run Pipeline', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('nav.close'), style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            if (_simulateStockShortage)
              ElevatedButton.icon(
                onPressed: _isActionExecuting || _isRunning ? null : _handleDelayDispatch,
                icon: _isActionExecuting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.schedule_send_rounded, size: 16),
                label: Text(
                  tr('predispatch.btn_delay_dispatch'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _isActionExecuting || _isRunning ? null : _handleProceedNormalDispatch,
                icon: _isActionExecuting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_clock_rounded, size: 16),
                label: Text(
                  tr('predispatch.btn_proceed_dispatch'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
