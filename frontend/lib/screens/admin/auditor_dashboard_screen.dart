import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auditor_service.dart';
import '../../models/auditor_model.dart';
import '../beneficiary/demo_login_screen.dart';

/// Comprehensive Production-Grade Vigilance Auditor Command Center
/// Government of Karnataka • Department of Food, Civil Supplies & Consumer Affairs
class AuditorDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const AuditorDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<AuditorDashboardScreen> createState() => _AuditorDashboardScreenState();
}

class _AuditorDashboardScreenState extends State<AuditorDashboardScreen> with SingleTickerProviderStateMixin {
  late final ApiService _apiService;
  late final AuditorService _auditorService;

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;

  // Active State
  String _activeCycle = '2026-09';
  List<String> _availableCycles = ['2026-09'];
  AuditOverviewModel? _overview;
  List<AuditRecordModel> _assignments = [];
  AuditRecordModel? _selectedAudit;

  // Active Workflow Stage Workspace (1..6)
  int _activeStage = 1;

  // Filters & Search
  String _searchQuery = '';
  String? _selectedDistrictFilter;
  String? _selectedRiskFilter;
  String _activeTableTab = 'MY_ASSIGNMENTS'; // MY_ASSIGNMENTS, ALL_AUDITS, EXCEPTIONS

  // Stage Data Caches
  Map<String, dynamic>? _activePdsChain;
  Map<String, dynamic>? _activeReconciliation;
  List<Map<String, dynamic>> _activeInspections = [];
  List<Map<String, dynamic>> _activeExceptions = [];
  List<Map<String, dynamic>> _aiInsights = [];
  List<Map<String, dynamic>> _aiAnomalies = [];
  List<Map<String, dynamic>> _aiRecommendations = [];
  List<Map<String, dynamic>> _traceChain = [];

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _planFpsController = TextEditingController(text: 'FPS-KA-BLR-002');
  final TextEditingController _findingTitleController = TextEditingController();
  final TextEditingController _findingDescController = TextEditingController();
  final TextEditingController _findingRecController = TextEditingController();
  final TextEditingController _reportScopeController = TextEditingController(text: 'Statutory Physical & Digital PDS Audit');
  final TextEditingController _reportObsController = TextEditingController();
  final TextEditingController _closeReasonController = TextEditingController(text: 'Statutory compliance verification and reconciliation completed.');
  final TextEditingController _traceEntityController = TextEditingController(text: 'FPS-KA-BLR-002');

  String _findingType = 'STOCK_VARIANCE';
  String _findingSeverity = 'MEDIUM';
  String _traceEntityType = 'FPS';

  // Theme Palette
  static const Color _navy = Color(0xFF0F172A);
  static const Color _cardNavy = Color(0xFF1E293B);
  static const Color _govBlue = Color(0xFF1E3A8A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF16A34A);
  static const Color _amber = Color(0xFFD97706);
  static const Color _red = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _auditorService = AuditorService(apiService: _apiService);
    _loadInitialAuditData();
  }

  Future<void> _loadInitialAuditData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cycles = await _auditorService.fetchCycles();
      final overview = await _auditorService.fetchOverview(cycleId: _activeCycle);
      final assignments = await _auditorService.fetchAssignments(cycleId: _activeCycle);
      final aiIns = await _auditorService.fetchAiInsights(cycleId: _activeCycle);
      final aiAnom = await _auditorService.fetchAiAnomalies(cycleId: _activeCycle);
      final aiRecs = await _auditorService.fetchAiRecommendations(cycleId: _activeCycle);

      setState(() {
        _availableCycles = cycles;
        _overview = overview;
        _assignments = assignments;
        _aiInsights = (aiIns['insights'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _aiAnomalies = (aiAnom['anomalies'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _aiRecommendations = aiRecs;
        if (assignments.isNotEmpty) {
          _selectedAudit = assignments.first;
          _activeStage = _selectedAudit!.currentStage;
        }
        _isLoading = false;
      });

      if (_selectedAudit != null) {
        _loadStageDataForAudit(_selectedAudit!.auditId);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load official Auditor portal records: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStageDataForAudit(String auditId) async {
    try {
      final detail = await _auditorService.fetchAuditDetail(auditId);
      final chain = await _auditorService.fetchAuditPdsChain(auditId);
      final recon = await _auditorService.fetchAuditReconciliation(auditId);
      final insp = await _auditorService.fetchAuditInspections(auditId);
      final exc = await _auditorService.fetchAuditExceptions(auditId);

      setState(() {
        _selectedAudit = detail;
        _activePdsChain = chain['chain_verification'] as Map<String, dynamic>?;
        _activeReconciliation = recon['reconciliation'] as Map<String, dynamic>?;
        _activeInspections = (insp['inspections'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _activeExceptions = (exc['exceptions'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (_) {}
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? _red : _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Workflow Stage Actions
  Future<void> _handlePlanAudit() async {
    final fpsId = _planFpsController.text.trim();
    if (fpsId.isEmpty) return;

    setState(() => _isActionLoading = true);
    try {
      final res = await _auditorService.createAudit(fpsId: fpsId, cycleId: _activeCycle);
      _showSnackbar('Audit assignment ${res['audit_id']} planned and scheduled.');
      await _loadInitialAuditData();
    } catch (e) {
      _showSnackbar('Failed to plan audit: $e', isError: true);
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleVerifyRecords() async {
    if (_selectedAudit == null) return;
    setState(() => _isActionLoading = true);
    try {
      await _auditorService.verifyRecords(_selectedAudit!.auditId);
      _showSnackbar('Stage 02 Completed: PDS supply chain records verified.');
      await _loadInitialAuditData();
    } catch (e) {
      _showSnackbar('Failed to verify records: $e', isError: true);
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleAddFinding() async {
    if (_selectedAudit == null || _findingTitleController.text.trim().isEmpty) return;
    setState(() => _isActionLoading = true);
    try {
      await _auditorService.addFinding(
        _selectedAudit!.auditId,
        findingType: _findingType,
        severity: _findingSeverity,
        title: _findingTitleController.text.trim(),
        description: _findingDescController.text.trim(),
        auditorRecommendation: _findingRecController.text.trim(),
      );
      _findingTitleController.clear();
      _findingDescController.clear();
      _findingRecController.clear();
      _showSnackbar('Auditor finding recorded successfully.');
      await _loadInitialAuditData();
    } catch (e) {
      _showSnackbar('Failed to record finding: $e', isError: true);
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleGenerateReport() async {
    if (_selectedAudit == null) return;
    setState(() => _isActionLoading = true);
    try {
      final res = await _auditorService.generateReport(
        _selectedAudit!.auditId,
        scopeText: _reportScopeController.text.trim(),
        auditObservations: _reportObsController.text.trim(),
      );
      _showSnackbar('Stage 05 Draft Generated: Hash ${res['report_hash'].substring(0, 16)}...');
      await _loadInitialAuditData();
    } catch (e) {
      _showSnackbar('Failed to generate report: $e', isError: true);
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleFinalizeReport() async {
    if (_selectedAudit == null) return;
    setState(() => _isActionLoading = true);
    try {
      await _auditorService.finalizeReport(_selectedAudit!.auditId);
      _showSnackbar('Audit report finalized for closure review.');
      await _loadInitialAuditData();
    } catch (e) {
      _showSnackbar('Failed to finalize report: $e', isError: true);
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCloseAudit() async {
    if (_selectedAudit == null) return;
    setState(() => _isActionLoading = true);
    try {
      await _auditorService.closeAudit(
        _selectedAudit!.auditId,
        closureReason: _closeReasonController.text.trim(),
      );
      _showSnackbar('Stage 06 Completed: Audit ${_selectedAudit!.auditId} closed & sealed.');
      await _loadInitialAuditData();
    } catch (e) {
      _showSnackbar('Failed to close audit: $e', isError: true);
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _runCrossPortalTrace() async {
    final eid = _traceEntityController.text.trim();
    if (eid.isEmpty) return;

    setState(() => _isActionLoading = true);
    try {
      final res = await _auditorService.fetchCrossPortalTrace(_traceEntityType, eid);
      setState(() {
        _traceChain = (res['trace_chain'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
      _showTraceModal();
    } catch (e) {
      _showSnackbar('Failed to trace record: $e', isError: true);
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // Top Header Bar
          _buildTopHeader(),

          // Main Workspace
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Welcome / Auditor Command Header
                            _buildWelcomeHeaderCard(),
                            const SizedBox(height: 20),

                            // 2. Core Audit Workflow Cycle (Horizontal Stepper 01..06)
                            _buildAuditWorkflowCycleBar(),
                            const SizedBox(height: 20),

                            // 3. Stage Specific Workspace Panel
                            _buildActiveStageWorkspace(),
                            const SizedBox(height: 24),

                            // 4. Assignments Table & Focus Split Panel
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: _buildAuditAssignmentsTable()),
                                const SizedBox(width: 20),
                                Expanded(flex: 4, child: _buildRightSidePanels()),
                              ],
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // UI COMPONENTS
  // -----------------------------------------------------------------------------

  Widget _buildTopHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: _navy,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            tooltip: 'Return to Login',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _cardNavy, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.verified_user_rounded, color: _amber, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AUDITOR PORTAL',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
              ),
              Text(
                'Karnataka Food & Civil Supplies • Audit, Compliance & Verification',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Spacer(),

          // Cycle Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _cardNavy, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF334155))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: _cardNavy,
                value: _activeCycle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: _availableCycles
                    .map((c) => DropdownMenuItem(value: c, child: Text('Cycle: $c')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _activeCycle = val);
                    _loadInitialAuditData();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Operational Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.4), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade500)),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                SizedBox(width: 6),
                Text('● Operational', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Audit Records',
            onPressed: _loadInitialAuditData,
          ),
          const SizedBox(width: 8),

          // Auditor Avatar
          CircleAvatar(
            backgroundColor: _accentBlue,
            radius: 18,
            child: Text(
              (widget.username ?? 'A').substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeaderCard() {
    final total = _overview?.totalAudits ?? 0;
    final active = _overview?.activeAudits ?? 0;
    final closed = _overview?.closedAudits ?? 0;
    final critical = _overview?.criticalRisks ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_navy, _cardNavy], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${widget.username ?? "State Vigilance Auditor"}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your role ensures transparency, accountability and better food security outcomes across Karnataka PDS distribution.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showPlanAuditModal,
                icon: const Icon(Icons.add_task_rounded, size: 18, color: Colors.white),
                label: const Text('Plan & Schedule Audit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _accentBlue, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard('Total Audits', '$total', Icons.assignment_outlined, Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard('Active Audits', '$active', Icons.pending_actions_rounded, Colors.orange),
              const SizedBox(width: 16),
              _buildStatCard('Closed Audits', '$closed', Icons.verified_outlined, Colors.green),
              const SizedBox(width: 16),
              _buildStatCard('Critical Warnings', '$critical', Icons.warning_amber_rounded, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFF0F172A).withOpacity(0.6), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF334155))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditWorkflowCycleBar() {
    final sb = _overview?.stageBreakdown ?? {};

    final stages = [
      {'num': 1, 'title': '01 PLAN & SCHEDULE', 'count': sb['stage_1_plan_schedule'] ?? 0, 'icon': Icons.edit_calendar_rounded},
      {'num': 2, 'title': '02 VERIFY RECORDS', 'count': sb['stage_2_verify_records'] ?? 0, 'icon': Icons.fact_check_rounded},
      {'num': 3, 'title': '03 INSPECT FPS', 'count': sb['stage_3_inspect_fps'] ?? 0, 'icon': Icons.storefront_rounded},
      {'num': 4, 'title': '04 ANALYZE COMPLIANCE', 'count': sb['stage_4_analyze_compliance'] ?? 0, 'icon': Icons.analytics_rounded},
      {'num': 5, 'title': '05 GENERATE REPORT', 'count': sb['stage_5_generate_report'] ?? 0, 'icon': Icons.picture_as_pdf_rounded},
      {'num': 6, 'title': '06 CLOSE AUDIT', 'count': sb['stage_6_close_audit'] ?? 0, 'icon': Icons.lock_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AUDIT WORKFLOW CYCLE',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govBlue, letterSpacing: 0.8),
          ),
          const SizedBox(height: 14),
          Row(
            children: stages.map((st) {
              final num = st['num'] as int;
              final isActive = _activeStage == num;
              final isCurrentAuditStage = _selectedAudit?.currentStage == num;

              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _activeStage = num),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isActive ? _govBlue : (isCurrentAuditStage ? Colors.blue.shade50 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isActive ? _govBlue : (isCurrentAuditStage ? _accentBlue : Colors.grey.shade300), width: isActive ? 2 : 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(st['icon'] as IconData, size: 18, color: isActive ? Colors.white : _navy),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.white24 : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${st['count']}',
                                style: TextStyle(color: isActive ? Colors.white : _govBlue, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          st['title'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : _navy,
                          ),
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

  Widget _buildActiveStageWorkspace() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STAGE 0$_activeStage WORKSPACE — ${_getStageTitle(_activeStage)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navy),
              ),
              const Spacer(),
              if (_selectedAudit != null)
                Text(
                  'Selected Audit: ${_selectedAudit!.auditId} (${_selectedAudit!.fpsId})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govBlue),
                ),
            ],
          ),
          const Divider(height: 20),
          _buildStageContent(),
        ],
      ),
    );
  }

  String _getStageTitle(int stage) {
    switch (stage) {
      case 1:
        return 'PLAN & SCHEDULE AUDIT ASSIGNMENT';
      case 2:
        return 'PDS SUPPLY CHAIN RECORD VERIFICATION & RECONCILIATION';
      case 3:
        return 'INSPECT FPS PHYSICAL RECORDS & EVIDENCE';
      case 4:
        return 'ANALYZE COMPLIANCE & RECORD AUDITOR FINDINGS';
      case 5:
        return 'GENERATE CRYPTOGRAPHICALLY SEALED AUDIT REPORT';
      case 6:
        return 'AUDIT VALIDATION & IMMUTABLE CLOSURE';
      default:
        return 'WORKFLOW';
    }
  }

  Widget _buildStageContent() {
    switch (_activeStage) {
      case 1:
        return _buildStage1Content();
      case 2:
        return _buildStage2Content();
      case 3:
        return _buildStage3Content();
      case 4:
        return _buildStage4Content();
      case 5:
        return _buildStage5Content();
      case 6:
        return _buildStage6Content();
      default:
        return const SizedBox();
    }
  }

  // Stage 01
  Widget _buildStage1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Plan and schedule new audit assignments based on AI risk signals and routine statutory cycles.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _planFpsController,
                decoration: const InputDecoration(
                  labelText: 'Target FPS ID',
                  hintText: 'FPS-KA-BLR-002',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isActionLoading ? null : _handlePlanAudit,
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 18),
              label: const Text('Schedule Audit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _govBlue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('AI AUDIT PRIORITIZATION RECOMMENDATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govBlue)),
        const SizedBox(height: 10),
        ..._aiRecommendations.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.psychology_rounded, color: _amber),
                title: Text('${r['target_fps_id']} — ${r['recommended_action']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Why: ${r['reason']} (Suggested Type: ${r['suggested_audit_type']})', style: const TextStyle(fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: () {
                    _planFpsController.text = r['target_fps_id']?.toString() ?? '';
                    _handlePlanAudit();
                  },
                  child: const Text('Schedule'),
                ),
              ),
            )),
      ],
    );
  }

  // Stage 02
  Widget _buildStage2Content() {
    final chain = _activePdsChain;
    final recon = _activeReconciliation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Trace and verify data integrity from Beneficiary Intent down to FPS e-PoS transactions.', style: TextStyle(fontSize: 13)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isActionLoading || _selectedAudit == null ? null : _handleVerifyRecords,
              icon: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 18),
              label: const Text('Mark Stage 02 Records Verified', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _green),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (chain != null) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricBadge('Registered Citizens', '${chain['beneficiary_records_count']}'),
              _buildMetricBadge('Citizen Intents', '${chain['citizen_intents_count']} (${chain['total_intent_rice_kg']}kg)'),
              _buildMetricBadge('Inbound Dispatches', '${chain['dispatches_count']} Gatepasses'),
              _buildMetricBadge('e-PoS Transactions', '${chain['epos_transactions_count']} Records'),
              _buildMetricBadge('Field Inspections', '${chain['inspection_records_count']} Verified'),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (recon != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RECORD RECONCILIATION (${recon['commodity']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _govBlue)),
                const SizedBox(height: 10),
                Text('Opening Stock: ${recon['opening_stock_kg']} kg • Distributed: ${recon['total_distributed_kg']} kg • Physical Balance: ${recon['actual_physical_stock_kg']} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Calculated Variance: ${recon['variance_kg']} kg (Status: ${recon['status']})', style: TextStyle(color: recon['status'] == 'MATCHED' ? _green : _red, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricBadge(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _govBlue)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  // Stage 03
  Widget _buildStage3Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review statutory physical verification logs recorded by Field Food Inspectors.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        if (_activeInspections.isEmpty)
          const Text('No field inspection records filed for this Fair Price Shop yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
        else
          ..._activeInspections.map((i) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.verified_outlined, color: _green),
                  title: Text('Inspection ${i['inspection_id'] ?? i['id']} — Compliance Score: ${i['compliance_score']}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Inspector: ${i['inspector_id']} • Remarks: ${i['remarks']} • Status: ${i['status']}', style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _govBlue, borderRadius: BorderRadius.circular(4)),
                    child: Text('Hash: ${(i['sealed_hash'] ?? 'VERIFIED').toString().substring(0, 8)}...', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              )),
      ],
    );
  }

  // Stage 04
  Widget _buildStage4Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Record official auditor findings, exceptions, and compliance observations.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _findingTitleController,
                decoration: const InputDecoration(labelText: 'Finding Title', hintText: 'e.g. Minor Inventory Discrepancy', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _findingSeverity,
              items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _findingSeverity = v!),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isActionLoading || _selectedAudit == null ? null : _handleAddFinding,
              icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
              label: const Text('Add Finding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _govBlue, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _findingDescController,
          decoration: const InputDecoration(labelText: 'Detailed Description', hintText: 'Explain the compliance finding...', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 16),
        if (_selectedAudit != null && _selectedAudit!.findings.isNotEmpty) ...[
          const Text('RECORDED AUDIT FINDINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govBlue)),
          const SizedBox(height: 8),
          ..._selectedAudit!.findings.map((f) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.assignment_late_rounded, color: f.severity == 'CRITICAL' ? _red : _amber),
                  title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${f.description} (Recorded by ${f.createdBy})', style: const TextStyle(fontSize: 12)),
                ),
              )),
        ],
      ],
    );
  }

  // Stage 05
  Widget _buildStage5Content() {
    final reportHash = _selectedAudit?.reportHash;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Generate and finalize the cryptographically sealed audit report.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: _reportScopeController,
          decoration: const InputDecoration(labelText: 'Audit Scope', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _reportObsController,
          decoration: const InputDecoration(labelText: 'Auditor Observations & Summary', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isActionLoading || _selectedAudit == null ? null : _handleGenerateReport,
              icon: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 18),
              label: const Text('Generate SHA-256 Sealed Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _govBlue),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isActionLoading || _selectedAudit == null || _selectedAudit!.reportId == null ? null : _handleFinalizeReport,
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              label: const Text('Finalize Report for Closure', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _green),
            ),
          ],
        ),
        if (reportHash != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade300)),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: _green, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('SHA-256 Digital Digest Seal: $reportHash', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _green))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Stage 06
  Widget _buildStage6Content() {
    final isClosed = _selectedAudit?.status == 'AUDIT_CLOSED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isClosed ? 'This audit is formally CLOSED and cryptographically sealed as immutable.' : 'Perform final validation checks and formally close the audit record.',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (!isClosed) ...[
          TextField(
            controller: _closeReasonController,
            decoration: const InputDecoration(labelText: 'Closure Confirmation Reason', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isActionLoading || _selectedAudit == null ? null : _handleCloseAudit,
            icon: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            label: const Text('CLOSE AUDIT & MARK IMMUTABLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: _red, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: _navy, size: 20),
                    SizedBox(width: 8),
                    Text('AUDIT SEALED & CLOSED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Closed At: ${_selectedAudit!.closedAt ?? "N/A"} • Closed By: ${_selectedAudit!.closedBy ?? "auditor_user"}'),
                Text('Reason: ${_selectedAudit!.closureReason ?? "Completed statutory verification"}'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAuditAssignmentsTable() {
    final filtered = _assignments.where((a) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!a.auditId.toLowerCase().contains(q) && !a.fpsId.toLowerCase().contains(q) && !a.fpsName.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_selectedDistrictFilter != null && a.district != _selectedDistrictFilter) return false;
      if (_selectedRiskFilter != null && a.riskLevel != _selectedRiskFilter) return false;
      if (_activeTableTab == 'EXCEPTIONS' && a.riskLevel != 'HIGH' && a.riskLevel != 'CRITICAL') return false;
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('AUDIT ASSIGNMENTS REGISTRY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
              const Spacer(),

              // Search
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(hintText: 'Search Audit ID / FPS...', isDense: true, prefixIcon: Icon(Icons.search, size: 18), border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table Tabs
          Row(
            children: [
              _buildTabChip('MY ASSIGNMENTS', 'MY_ASSIGNMENTS'),
              const SizedBox(width: 8),
              _buildTabChip('ALL AUDITS', 'ALL_AUDITS'),
              const SizedBox(width: 8),
              _buildTabChip('EXCEPTIONS', 'EXCEPTIONS'),
              const Spacer(),

              // Trace Trigger
              TextButton.icon(
                onPressed: _showTraceModal,
                icon: const Icon(Icons.hub_outlined, size: 16),
                label: const Text('Cross-Portal Trace Engine'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Data Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
              columns: const [
                DataColumn(label: Text('Audit ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('FPS / Shop Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('District', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Stage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Risk Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: filtered.map((a) {
                final isSel = _selectedAudit?.auditId == a.auditId;

                return DataRow(
                  selected: isSel,
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedAudit = a;
                      _activeStage = a.currentStage;
                    });
                    _loadStageDataForAudit(a.auditId);
                  },
                  cells: [
                    DataCell(Text(a.auditId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _govBlue))),
                    DataCell(Text('${a.fpsName} (${a.fpsId})', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(a.district, style: const TextStyle(fontSize: 12))),
                    DataCell(Text('Stage 0${a.currentStage}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: a.status == 'AUDIT_CLOSED' ? Colors.green.shade100 : Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text(a.status, style: TextStyle(color: a.status == 'AUDIT_CLOSED' ? _green : _govBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: a.riskLevel == 'CRITICAL' ? Colors.red.shade100 : (a.riskLevel == 'HIGH' ? Colors.orange.shade100 : Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
                        child: Text(a.riskLevel, style: TextStyle(color: a.riskLevel == 'CRITICAL' ? _red : (a.riskLevel == 'HIGH' ? _amber : Colors.black87), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedAudit = a;
                            _activeStage = a.currentStage;
                          });
                          _loadStageDataForAudit(a.auditId);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _govBlue, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        child: const Text('Inspect Stage', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String tabKey) {
    final isAct = _activeTableTab == tabKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAct ? Colors.white : _navy)),
      selected: isAct,
      selectedColor: _govBlue,
      onSelected: (val) => setState(() => _activeTableTab = tabKey),
    );
  }

  Widget _buildRightSidePanels() {
    return Column(
      children: [
        // Current Audit Focus Panel
        _buildCurrentAuditFocusPanel(),
        const SizedBox(height: 20),

        // AI Compliance Intelligence Panel
        _buildAiIntelligencePanel(),
      ],
    );
  }

  Widget _buildCurrentAuditFocusPanel() {
    final a = _selectedAudit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.center_focus_strong_rounded, color: _govBlue, size: 18),
              SizedBox(width: 8),
              Text('CURRENT AUDIT FOCUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govBlue)),
            ],
          ),
          const Divider(height: 16),
          if (a == null)
            const Text('No audit assignment selected.', style: TextStyle(color: Colors.grey))
          else ...[
            Text(a.auditId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
            const SizedBox(height: 4),
            Text('${a.fpsName} (${a.fpsId})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('District: ${a.district} • Cycle: ${a.cycleId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Stage: ${a.stageName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govBlue))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: a.riskLevel == 'CRITICAL' ? Colors.red.shade100 : Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text('Risk: ${a.riskLevel}', style: TextStyle(color: a.riskLevel == 'CRITICAL' ? _red : _govBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Assigned Team: ${a.assignedTeam}', style: const TextStyle(fontSize: 11)),
            Text('Risk Reason: ${a.riskReason}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildAiIntelligencePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_rounded, color: _amber, size: 18),
              SizedBox(width: 8),
              Text('AI COMPLIANCE INTELLIGENCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govBlue)),
            ],
          ),
          const Divider(height: 16),
          ..._aiInsights.map((ins) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ins['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
                    const SizedBox(height: 2),
                    Text('Why: ${ins['why']}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showPlanAuditModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plan & Schedule Audit Assignment'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _planFpsController,
                decoration: const InputDecoration(labelText: 'FPS ID', hintText: 'FPS-KA-BLR-002'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handlePlanAudit();
            },
            child: const Text('Plan Audit'),
          ),
        ],
      ),
    );
  }

  void _showTraceModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.hub_outlined, color: _govBlue),
            SizedBox(width: 8),
            Text('Cross-Portal End-to-End Trace Engine'),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 450,
          child: Column(
            children: [
              Row(
                children: [
                  DropdownButton<String>(
                    value: _traceEntityType,
                    items: ['FPS', 'BENEFICIARY', 'MANIFEST', 'TRANSACTION', 'AUDIT']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _traceEntityType = v!),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _traceEntityController,
                      decoration: const InputDecoration(hintText: 'Entity ID...', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: _runCrossPortalTrace, child: const Text('Trace')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _traceChain.length,
                  itemBuilder: (context, idx) {
                    final item = _traceChain[idx];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _govBlue,
                        radius: 12,
                        child: Text('${item['step']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      title: Text('${item['layer']} — ${item['entity']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      subtitle: Text(item['details']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text(item['status']?.toString() ?? 'VERIFIED', style: const TextStyle(color: _green, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: _red, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadInitialAuditData, child: const Text('Retry Connection')),
        ],
      ),
    );
  }
}
