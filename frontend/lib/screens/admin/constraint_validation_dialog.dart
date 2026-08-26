import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class ConstraintValidationDialog extends StatefulWidget {
  final String cycleId;
  final String? initialFpsId;

  const ConstraintValidationDialog({
    super.key,
    this.cycleId = '2026-09',
    this.initialFpsId,
  });

  @override
  State<ConstraintValidationDialog> createState() =>
      _ConstraintValidationDialogState();
}

class _ConstraintValidationDialogState
    extends State<ConstraintValidationDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isRevalidating = false;
  String? _errorMessage;

  ConstraintAuditResult? _auditData;
  String _selectedScenario = 'NORMAL'; // 'NORMAL' or 'FAILURE_SIMULATION'
  String _selectedFpsFilter = 'ALL'; // 'ALL' or specific fps_id

  @override
  void initState() {
    super.initState();
    if (widget.initialFpsId != null && widget.initialFpsId!.isNotEmpty) {
      _selectedFpsFilter = widget.initialFpsId!;
    }
    _loadAuditData();
  }

  Future<void> _loadAuditData({String scenario = 'NORMAL'}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedScenario = scenario;
    });

    try {
      final res = await _apiService.fetchDistrictConstraints(
        cycleId: widget.cycleId,
        scenario: scenario,
      );
      if (mounted) {
        setState(() {
          _auditData = res;
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

  Future<void> _revalidateAudit() async {
    setState(() => _isRevalidating = true);

    try {
      final res = await _apiService.revalidateConstraints(
        cycleId: widget.cycleId,
        scenario: _selectedScenario,
      );
      if (mounted) {
        setState(() {
          _auditData = res;
          _isRevalidating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.districtValidationStatus == 'PASS'
                  ? 'All 9 constraints verified! Status: PASS'
                  : 'Revalidation completed: ${res.failCount} failure(s) remaining.',
            ),
            backgroundColor: res.districtValidationStatus == 'PASS'
                ? AppConstants.successGreen
                : AppConstants.dangerRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRevalidating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revalidation failed: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _resolveConstraint(String fpsId, String action,
      {Map<String, dynamic>? parameters}) async {
    try {
      final res = await _apiService.resolveFpsConstraint(
        fpsId,
        action,
        parameters: parameters,
        cycleId: widget.cycleId,
      );
      await _loadAuditData(scenario: _selectedScenario);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppConstants.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve constraint: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  void _showResolutionSheet(String fpsId, ConstraintCheckItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.build_circle_outlined,
                      color: AppConstants.primaryNavy, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Resolve Constraint: ${item.name}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.explanation,
                style: const TextStyle(
                    fontSize: 12, color: AppConstants.textSecondary),
              ),
              const Divider(height: 20),
              const Text('SELECT REMEDIATION ACTION:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textSecondary)),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.local_shipping,
                    color: AppConstants.accentBlue),
                title: const Text('Assign 10-Ton Heavy Haulage Carrier',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Upgrades vehicle to DEMO-KA-04-E-1021 (10,000 kg capacity)',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _resolveConstraint(fpsId, 'SELECT_ALTERNATE_TRUCK');
                },
              ),
              ListTile(
                leading: const Icon(Icons.call_split,
                    color: AppConstants.purpleAccent),
                title: const Text('Split Quantity across 2 Staggered Trips',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Partition shipment into 50% morning and 50% afternoon deliveries',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _resolveConstraint(fpsId, 'SPLIT_QUANTITY');
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune, color: AppConstants.successGreen),
                title: const Text('Adjust Dispatch Quantity to Fit Vehicle',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Trim dispatch quantity down to fit exact vehicle payload rating',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _resolveConstraint(fpsId, 'ADJUST_DISPATCH_QUANTITY',
                      parameters: {'adjusted_quantity_kg': 2000.0});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: 1100,
        height: 840,
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
                      Text('Running 9-Rule Constraint & Statutory Validation...',
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
                        onPressed: () => _loadAuditData(),
                        child: const Text('Retry Audit'),
                      )
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildScrollableBody()),
            const SizedBox(height: 12),
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
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rule_folder_outlined,
                  color: Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pre-Dispatch Constraint & Rule Validation Engine',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  '9 Statutory & Logistics Rules • Never Silently Corrects • Manifest Lock Guard',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                  ),
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

  Widget _buildScrollableBody() {
    final audit = _auditData!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Scenario Selector & Quick Revalidate Controls
          _buildScenarioSelector(),
          const SizedBox(height: 12),

          // 2. Critical Failure Banner (if any failure exists)
          if (audit.districtValidationStatus == 'FAIL')
            _buildCriticalFailureAlertBanner(audit),
          const SizedBox(height: 12),

          // 3. Top KPI Summary Grid (Pass, Warning, Fail)
          _buildKpiSummaryBar(audit),
          const SizedBox(height: 14),

          // 4. 9-Rule Itemized Inspection List
          _buildNineRulesList(audit),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text('TEST SCENARIO:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textSecondary)),
                ElevatedButton.icon(
                  onPressed: () => _loadAuditData(scenario: 'NORMAL'),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('1. Normal Compliant (READY)',
                      style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedScenario == 'NORMAL'
                        ? AppConstants.successGreen
                        : Colors.grey.shade200,
                    foregroundColor: _selectedScenario == 'NORMAL'
                        ? Colors.white
                        : AppConstants.textPrimary,
                    elevation: _selectedScenario == 'NORMAL' ? 2 : 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _loadAuditData(scenario: 'STORAGE_FAILURE_SIMULATION'),
                  icon: const Icon(Icons.warehouse_outlined, size: 14),
                  label: const Text('2. Simulate FPS Capacity Drop (BLOCKED)',
                      style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedScenario == 'STORAGE_FAILURE_SIMULATION'
                        ? AppConstants.dangerRed
                        : Colors.grey.shade200,
                    foregroundColor: _selectedScenario == 'STORAGE_FAILURE_SIMULATION'
                        ? Colors.white
                        : AppConstants.textPrimary,
                    elevation: _selectedScenario == 'STORAGE_FAILURE_SIMULATION' ? 2 : 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _loadAuditData(scenario: 'FAILURE_SIMULATION'),
                  icon: const Icon(Icons.local_shipping_outlined, size: 14),
                  label: const Text('3. Simulate Fleet Overload (BLOCKED)',
                      style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedScenario == 'FAILURE_SIMULATION'
                        ? AppConstants.dangerRed
                        : Colors.grey.shade200,
                    foregroundColor: _selectedScenario == 'FAILURE_SIMULATION'
                        ? Colors.white
                        : AppConstants.textPrimary,
                    elevation: _selectedScenario == 'FAILURE_SIMULATION' ? 2 : 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isRevalidating ? null : _revalidateAudit,
            icon: _isRevalidating
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Revalidate',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalFailureAlertBanner(ConstraintAuditResult audit) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.dangerRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.dangerRed.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.gpp_bad_rounded, color: AppConstants.dangerRed, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSTRAINT NOT SATISFIED — MANIFEST LOCKING BLOCKED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.dangerRed,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Critical logistics constraints have failed. Government supply-chain rules prevent manifest lock until all critical violations are resolved.',
                  style: TextStyle(
                      fontSize: 11, color: AppConstants.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBar(ConstraintAuditResult audit) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            'TOTAL AUDITED',
            '${audit.totalFpsAudited} FPS',
            'District Bengaluru Urban',
            Icons.domain,
            AppConstants.primaryNavy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCard(
            'FULLY COMPLIANT',
            '${audit.passCount} PASS',
            'Satisfies all 9 rules',
            Icons.check_circle_outline,
            AppConstants.successGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCard(
            'WARNINGS',
            '${audit.warningCount} WARN',
            'Operational advisories',
            Icons.warning_amber_rounded,
            AppConstants.accentAmber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCard(
            'CRITICAL FAILURES',
            '${audit.failCount} FAIL',
            audit.failCount > 0 ? 'Action Required' : '0 Violations',
            Icons.highlight_off_rounded,
            audit.failCount > 0
                ? AppConstants.dangerRed
                : AppConstants.successGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, String subtitle,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textSecondary)),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 9, color: AppConstants.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNineRulesList(ConstraintAuditResult audit) {
    // Pick the primary FPS being inspected (or first one)
    final selectedEvaluation = audit.fpsEvaluations.firstWhere(
      (e) =>
          _selectedFpsFilter == 'ALL' || e.fpsId == _selectedFpsFilter,
      orElse: () => audit.fpsEvaluations.first,
    );

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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryNavy,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(selectedEvaluation.fpsId,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${selectedEvaluation.fpsName} — 9-Rule Itemized Validation Dossier',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selectedEvaluation.overallStatus == 'PASS'
                      ? AppConstants.successGreen.withValues(alpha: 0.12)
                      : (selectedEvaluation.overallStatus == 'WARNING'
                          ? AppConstants.accentAmber.withValues(alpha: 0.12)
                          : AppConstants.dangerRed.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'STATUS: ${selectedEvaluation.overallStatus}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selectedEvaluation.overallStatus == 'PASS'
                        ? AppConstants.successGreen
                        : (selectedEvaluation.overallStatus == 'WARNING'
                            ? AppConstants.accentAmber
                            : AppConstants.dangerRed),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...selectedEvaluation.checks.map((chk) {
            return _buildConstraintCheckRow(selectedEvaluation.fpsId, chk);
          }),
        ],
      ),
    );
  }

  Widget _buildConstraintCheckRow(String fpsId, ConstraintCheckItem chk) {
    Color statusColor;
    IconData statusIcon;

    if (chk.status == 'PASS') {
      statusColor = AppConstants.successGreen;
      statusIcon = Icons.check_circle;
    } else if (chk.status == 'WARNING') {
      statusColor = AppConstants.accentAmber;
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = AppConstants.dangerRed;
      statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: chk.status == 'FAIL'
            ? AppConstants.dangerRed.withValues(alpha: 0.04)
            : AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: chk.status == 'FAIL'
                ? AppConstants.dangerRed.withValues(alpha: 0.4)
                : AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    chk.name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      chk.severity,
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
              if (chk.status == 'FAIL')
                ElevatedButton.icon(
                  onPressed: () => _showResolutionSheet(fpsId, chk),
                  icon: const Icon(Icons.build, size: 12),
                  label: const Text('Resolve Constraint',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.dangerRed,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            chk.explanation,
            style: const TextStyle(
                fontSize: 11,
                color: AppConstants.textPrimary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Actual: ${chk.actualValue}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryNavy)),
              const SizedBox(width: 12),
              Text('Required: ${chk.requiredValue}',
                  style: const TextStyle(
                      fontSize: 10, color: AppConstants.textSecondary)),
            ],
          ),
          if (chk.suggestedResolution != null) ...[
            const SizedBox(height: 4),
            Text(
              'Recommended Action: ${chk.suggestedResolution}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Notice: DEMO DATA — NOT GOVERNMENT DATA (CONSTRAINT VALIDATION ENGINE)',
          style: TextStyle(fontSize: 10, color: AppConstants.textTertiary),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
