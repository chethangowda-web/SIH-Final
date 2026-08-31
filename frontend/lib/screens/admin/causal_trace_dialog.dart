import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class CausalTraceDialog extends StatefulWidget {
  final ApiService? apiService;
  final String initialFpsId;
  final String cycleId;

  const CausalTraceDialog({
    super.key,
    this.apiService,
    this.initialFpsId = 'FPS-KA-BLR-001',
    this.cycleId = '2026-09',
  });

  @override
  State<CausalTraceDialog> createState() => _CausalTraceDialogState();
}

class _CausalTraceDialogState extends State<CausalTraceDialog> {
  late final ApiService _apiService;
  late String _selectedFpsId;
  bool _isLoading = true;
  bool _isSimulating = false;
  String? _errorMessage;
  CausalTraceRun? _currentRun;
  CausalTraceRun? _previousRun;
  CausalDeltaSummary? _causalDelta;

  final List<Map<String, String>> _fpsList = [
    {'id': 'FPS-KA-BLR-001', 'name': 'FPS-KA-BLR-001 — Malleshwaram Seva Kendra'},
    {'id': 'FPS-KA-BLR-005', 'name': 'FPS-KA-BLR-005 — Bellandur Outer Ring Road'},
    {'id': 'FPS-KA-BLR-013', 'name': 'FPS-KA-BLR-013 — Peenya Industrial Area'},
    {'id': 'FPS-KA-BLR-017', 'name': 'FPS-KA-BLR-017 — Kengeri Satellite Town'},
    {'id': 'FPS-KA-BLR-019', 'name': 'FPS-KA-BLR-019 — Hebbal Godown Point'},
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _selectedFpsId = widget.initialFpsId;
    _loadCausalTrace();
  }

  Future<void> _loadCausalTrace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final run = await _apiService.fetchCausalTrace(
        cycleId: widget.cycleId,
        fpsId: _selectedFpsId,
      );
      if (mounted) {
        setState(() {
          _currentRun = run;
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

  Future<void> _runCalculation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final run = await _apiService.runCausalTraceCalculation(
        cycleId: widget.cycleId,
        fpsId: _selectedFpsId,
      );
      if (mounted) {
        setState(() {
          _previousRun = _currentRun;
          _currentRun = run;
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

  Future<void> _injectSyntheticIntentShift() async {
    setState(() {
      _isSimulating = true;
      _errorMessage = null;
    });

    try {
      final resp = await _apiService.simulateIntentShiftCausalTrace(
        cycleId: widget.cycleId,
        fpsId: _selectedFpsId,
        shiftDeltaKg: 150.0,
        beneficiaryId: 'BEN-KA-0001',
      );

      if (mounted) {
        setState(() {
          _currentRun = resp.currentRun;
          _previousRun = resp.previousRun;
          _causalDelta = resp.causalDelta;
          _isSimulating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSimulating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160, maxHeight: 840),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildCommandRibbon(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(strokeWidth: 3, color: AppConstants.primaryNavy),
                            SizedBox(height: 16),
                            Text('Loading 7-stage causal pipeline trace...', style: TextStyle(fontSize: 13, color: AppConstants.textSecondary)),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 44, color: AppConstants.dangerRed),
                                  const SizedBox(height: 12),
                                  Text(_errorMessage!, style: const TextStyle(color: AppConstants.dangerRed), textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _loadCausalTrace,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry Trace'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildBody(),
              ),
              _buildStickyFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: const BoxDecoration(
        color: AppConstants.primaryNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_tree_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'End-to-End Causal Pipeline Trace',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(width: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF15803D),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Text(
                          'DETERMINISTIC PROPAGATION',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Intent Signals → Forecast D̂ → Constraints → Dispatch Q* → TSP Route → Locked Manifest → SHA-256 Digital Seal',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // COMMAND RIBBON
  Widget _buildCommandRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        border: Border(bottom: BorderSide(color: AppConstants.cardBorder)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: AppConstants.primaryNavy),
              const SizedBox(width: 8),
              const Text('Target FPS Scope:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
              const SizedBox(width: 10),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppConstants.cardBorder),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedFpsId,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: AppConstants.textPrimary, fontWeight: FontWeight.w600),
                    items: _fpsList.map((fps) {
                      return DropdownMenuItem<String>(
                        value: fps['id'],
                        child: Text(fps['name']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedFpsId) {
                        setState(() {
                          _selectedFpsId = val;
                          _causalDelta = null;
                        });
                        _loadCausalTrace();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _runCalculation,
                icon: const Icon(Icons.sync_rounded, size: 15),
                label: const Text('Re-Run Operational Trace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.primaryNavy,
                  side: const BorderSide(color: AppConstants.primaryNavy),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isSimulating ? null : _injectSyntheticIntentShift,
                icon: _isSimulating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bolt_rounded, size: 15),
                label: const Text('Inject Intent Shift (+150 kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentAmber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // BODY
  Widget _buildBody() {
    final run = _currentRun!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_causalDelta != null) ...[
            _buildCausalDeltaBanner(),
            const SizedBox(height: 18),
          ],
          _buildStageCard(run.stage1Intent, Icons.record_voice_over_outlined, AppConstants.accentBlue),
          const SizedBox(height: 12),
          _buildStageCard(run.stage2Forecast, Icons.insights_rounded, const Color(0xFF7C3AED)),
          const SizedBox(height: 12),
          _buildStageCard(run.stage3Constraints, Icons.rule_folder_outlined, AppConstants.tealAccent),
          const SizedBox(height: 12),
          _buildStageCard(run.stage4Dispatch, Icons.tune_rounded, AppConstants.accentAmber),
          const SizedBox(height: 12),
          _buildStageCard(run.stage5Route, Icons.route_rounded, AppConstants.accentBlue),
          const SizedBox(height: 12),
          _buildStageCard(run.stage6Manifest, Icons.fact_check_outlined, AppConstants.primaryNavy),
          const SizedBox(height: 12),
          _buildStageCard(run.stage7Seal, Icons.verified_user_outlined, const Color(0xFF15803D)),
        ],
      ),
    );
  }

  // CAUSAL DELTA HIGHLIGHT BANNER
  Widget _buildCausalDeltaBanner() {
    final d = _causalDelta!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Amber highlight
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: Color(0xFF92400E), size: 18),
              const SizedBox(width: 8),
              const Text(
                'LIVE CAUSAL PROPAGATION DELTA DETECTED',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'STATUTORY ENTITLE: +0.0 kg (INVARIANT)',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(d.propagationSummary, style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.35)),
          if (_previousRun != null) ...[
            const SizedBox(height: 6),
            Text(
              'Baseline Run: ${_previousRun!.runId}  →  Active Run: ${_currentRun?.runId ?? ""}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildDeltaTag('Intent Δ', '${d.intentDeltaKg >= 0 ? '+' : ''}${d.intentDeltaKg.toStringAsFixed(1)} kg', AppConstants.accentBlue),
              _buildDeltaTag('Forecast (D̂) Δ', '${d.forecastDeltaKg >= 0 ? '+' : ''}${d.forecastDeltaKg.toStringAsFixed(1)} kg', const Color(0xFF7C3AED)),
              _buildDeltaTag('Dispatch (Q*) Δ', '${d.dispatchDeltaKg >= 0 ? '+' : ''}${d.dispatchDeltaKg.toStringAsFixed(1)} kg', AppConstants.accentAmber),
              _buildDeltaTag('Corridor Payload Δ', '${d.routePayloadDeltaKg >= 0 ? '+' : ''}${d.routePayloadDeltaKg.toStringAsFixed(1)} kg', AppConstants.primaryNavy),
              _buildDeltaTag('Digital Seal', d.sealHashChanged ? 'NEW SHA-256 HASH' : 'UNCHANGED', const Color(0xFF15803D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
          Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // STAGE CARD
  Widget _buildStageCard(CausalStageTraceModel stage, IconData icon, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: themeColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'STAGE ${stage.stageNumber}: ${stage.title}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  stage.status,
                  style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INPUT PARAMETERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppConstants.textSecondary)),
                      const SizedBox(height: 6),
                      ...stage.inputSummary.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11, color: AppConstants.textPrimary)),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('OUTPUT METRICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppConstants.textSecondary)),
                      const SizedBox(height: 6),
                      ...stage.outputSummary.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11, color: AppConstants.textPrimary, fontWeight: FontWeight.w600)),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Governance Rule: ${stage.governanceNotes}',
            style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppConstants.textSecondary),
          ),
        ],
      ),
    );
  }

  // STICKY FOOTER
  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppConstants.cardBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF15803D)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'NFSA Governance Assurance: Citizen intent is strictly an advisory demand signal. Card statutory entitlement is 100% invariant.',
              style: TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSmall)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
