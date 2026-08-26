import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class SihDemoModeDialog extends StatefulWidget {
  final String cycleId;

  const SihDemoModeDialog({
    super.key,
    this.cycleId = '2026-09',
  });

  static void show(BuildContext context, {String cycleId = '2026-09'}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SihDemoModeDialog(cycleId: cycleId),
    );
  }

  @override
  State<SihDemoModeDialog> createState() => _SihDemoModeDialogState();
}

class _SihDemoModeDialogState extends State<SihDemoModeDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isRunningScenario = false;
  String? _errorMessage;

  List<SihDemoScenario> _scenarios = [];
  String _selectedScenarioId = 'SCENARIO_1';
  DemoScenarioExecutionResult? _executionResult;
  SystemImpactDashboardData? _impactData;

  int _currentStepIndex = 0;
  Timer? _autoPlayTimer;
  bool _isAutoPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final scenarios = await _apiService.fetchSihDemoScenarios();
      final impact = await _apiService.fetchSystemImpactData(cycleId: widget.cycleId);
      final exec = await _apiService.runSihDemoScenario(
        scenarioId: _selectedScenarioId,
        cycleId: widget.cycleId,
      );

      if (mounted) {
        setState(() {
          _scenarios = scenarios;
          _impactData = impact;
          _executionResult = exec;
          _currentStepIndex = exec.stepsTrace.length - 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runSelectedScenario({String? scenarioId, bool autoPlay = false}) async {
    final sid = scenarioId ?? _selectedScenarioId;
    _autoPlayTimer?.cancel();

    setState(() {
      _isRunningScenario = true;
      _selectedScenarioId = sid;
      _isAutoPlaying = autoPlay;
      _currentStepIndex = autoPlay ? 0 : 0;
    });

    try {
      final exec = await _apiService.runSihDemoScenario(
        scenarioId: sid,
        cycleId: widget.cycleId,
      );
      final impact = await _apiService.fetchSystemImpactData(cycleId: widget.cycleId);

      if (mounted) {
        setState(() {
          _executionResult = exec;
          _impactData = impact;
          _isRunningScenario = false;
        });

        if (autoPlay) {
          _startAutoPlay(exec.stepsTrace.length);
        } else {
          setState(() => _currentStepIndex = exec.stepsTrace.length - 1);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunningScenario = false;
          _isAutoPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to execute scenario: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  void _startAutoPlay(int totalSteps) {
    setState(() {
      _isAutoPlaying = true;
      _currentStepIndex = 0;
    });

    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentStepIndex < totalSteps - 1) {
        setState(() => _currentStepIndex++);
      } else {
        timer.cancel();
        setState(() => _isAutoPlaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('14-Step SIH Operational Scenario successfully executed end-to-end!'),
            backgroundColor: AppConstants.successGreen,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: 1280,
        height: 900,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConstants.primaryNavy),
                      SizedBox(height: 12),
                      Text('Initializing SIH 2026 Demonstration Control Center...',
                          style: TextStyle(
                              color: AppConstants.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppConstants.dangerRed, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style: const TextStyle(
                              color: AppConstants.dangerRed,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInitialData,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildMainScrollableContent()),
            const SizedBox(height: 10),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppConstants.primaryNavy, Color(0xFF1E3A8A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 26),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'SIH 2026 Demo Mode: End-to-End Operational Pipeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'JUDGE DEMO READY',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const Text(
                  '14-Step Closed-Loop Flow: Forecast → Recommended Quantity → 9 Constraints → Optimization → Locked Manifest → Gatepass → Notification → Feedback',
                  style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildMainScrollableContent() {
    final exec = _executionResult;
    final impact = _impactData;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Scenario Selector & Action Bar
          _buildScenarioSelectorCard(),
          const SizedBox(height: 14),

          // 2. Core Value Chain Flow Banner (Forecast -> Decide -> Lock -> Notify)
          _buildCoreValueChainBanner(),
          const SizedBox(height: 14),

          // 3. 14-Step Interactive Execution Stepper & Trace Details
          if (exec != null) _build14StepExecutionTraceCard(exec),
          const SizedBox(height: 14),

          // 4. System Impact Dashboard (7 KPIs)
          if (impact != null) _buildSystemImpactSection(impact),
        ],
      ),
    );
  }

  Widget _buildScenarioSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SELECT SIH DEMONSTRATION SCENARIO:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isRunningScenario
                        ? null
                        : () => _runSelectedScenario(autoPlay: false),
                    icon: const Icon(Icons.play_arrow_outlined, size: 16),
                    label: const Text('Execute Scenario (Instant)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.primaryNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isRunningScenario || _isAutoPlaying
                        ? null
                        : () => _runSelectedScenario(autoPlay: true),
                    icon: _isAutoPlaying
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.movie_filter_outlined, size: 16),
                    label: Text(
                      _isAutoPlaying ? 'Auto-Playing Pipeline...' : 'Auto-Play 14-Step Demo (2 Min)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 4 Scenario Cards
          Row(
            children: _scenarios.map((s) {
              final isSelected = s.id == _selectedScenarioId;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _runSelectedScenario(scenarioId: s.id, autoPlay: false),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppConstants.primaryNavy.withValues(alpha: 0.05)
                          : AppConstants.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppConstants.primaryNavy : AppConstants.cardBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? AppConstants.primaryNavy : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                s.badge,
                                style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppConstants.primaryNavy),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.title.split(':').last.trim(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppConstants.primaryNavy : AppConstants.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.description,
                          style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreValueChainBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryNavy.withValues(alpha: 0.08),
            AppConstants.accentBlue.withValues(alpha: 0.08)
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppConstants.primaryNavy, size: 20),
              SizedBox(width: 10),
              Text(
                'CORE SYSTEM USP:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppConstants.primaryNavy),
              ),
              SizedBox(width: 8),
              Text(
                '“Forecast → Decide → Lock → Notify”',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          Text(
            'Interoperable Pre-Dispatch Intelligence Layer (SIH 2026)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _build14StepExecutionTraceCard(DemoScenarioExecutionResult exec) {
    final activeStep = exec.stepsTrace[_currentStepIndex.clamp(0, exec.stepsTrace.length - 1)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  const Icon(Icons.account_tree_outlined,
                      color: AppConstants.primaryNavy, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '14-Step Operational Pre-Dispatch Trace (${exec.scenarioTitle})',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Text(
                'Step ${_currentStepIndex + 1} of ${exec.stepsTrace.length} • Execution: ${exec.executionTimeSeconds.toStringAsFixed(2)}s',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textSecondary),
              ),
            ],
          ),
          const Divider(height: 16),

          // Horizontal Progress Mini-Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(exec.stepsTrace.length, (idx) {
                final isPassed = idx <= _currentStepIndex;
                final isCurrent = idx == _currentStepIndex;

                return GestureDetector(
                  onTap: () => setState(() => _currentStepIndex = idx),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppConstants.primaryNavy
                          : (isPassed ? AppConstants.successGreen : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPassed || isCurrent ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Active Step Detail Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppConstants.primaryNavy,
                          child: Text('${activeStep.stepNumber}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activeStep.title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryNavy),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppConstants.purpleAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        activeStep.phase,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.purpleAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activeStep.summary,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textPrimary),
                ),
                const SizedBox(height: 8),
                // Raw attributes key-value chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: activeStep.details.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppConstants.cardBorder),
                      ),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(
                            fontSize: 9,
                            fontFamily: 'Courier',
                            color: AppConstants.textSecondary),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemImpactSection(SystemImpactDashboardData impact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up_rounded,
                      color: AppConstants.successGreen, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'System Impact Dashboard (Prototype Simulation Results)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Text(
                impact.prototypeLabel,
                style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppConstants.textSecondary),
              ),
            ],
          ),
          const Divider(height: 16),
          // 7 Impact Metric KPI Cards
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: impact.impactMetrics.values.map((m) {
              return SizedBox(
                width: 280,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              m.label,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppConstants.successGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${m.improvementPct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.successGreen),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('Baseline: ${m.baselineValue}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppConstants.textSecondary)),
                          const Text(' → ',
                              style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(m.optimizedValue,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.primaryNavy)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.description,
                        style: const TextStyle(fontSize: 9, color: AppConstants.textTertiary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Notice: PROTOTYPE SIMULATION — SMART INDIA HACKATHON 2026 DEMO ENGINE',
          style: TextStyle(fontSize: 10, color: AppConstants.textTertiary),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close Demo Center'),
        ),
      ],
    );
  }
}
