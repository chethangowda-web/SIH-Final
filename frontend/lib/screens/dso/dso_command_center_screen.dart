import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/dso/dso_service.dart';
import '../../services/auth_session.dart';
import '../../models/dso/dso_models.dart';
import '../../widgets/dso/dso_sidebar.dart';
import '../../widgets/dso/dso_top_header.dart';
import '../../widgets/dso/dso_ai_panel.dart';
import '../../widgets/dso/dso_decision_trace_drawer.dart';
import '../../widgets/dso/dso_data_source_modal.dart';
import '../../widgets/dso/dso_exception_queue.dart';
import 'dso_monitor_view.dart';
import 'dso_validate_demand_view.dart';
import 'dso_allocation_view.dart';
import 'dso_optimization_view.dart';
import 'dso_dispatch_view.dart';
import 'dso_delivery_view.dart';
import 'dso_evaluation_view.dart';

class DsoCommandCenterScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const DsoCommandCenterScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<DsoCommandCenterScreen> createState() => _DsoCommandCenterScreenState();
}

class _DsoCommandCenterScreenState extends State<DsoCommandCenterScreen> {
  late DsoService _dsoService;
  int _selectedNavIndex = 0;
  String _activeCycle = '2026-09';
  String _selectedDistrict = 'Ramanagara';
  List<String> _availableDistricts = ['Ramanagara', 'Bengaluru Urban', 'Mandya'];
  String _exceptionSeverityFilter = 'ALL';
  bool _showAiPanel = true;
  bool _showTraceDrawer = false;

  bool _loading = true;
  String? _error;
  DsoCommandOverview? _overview;
  List<GovernanceEventItem> _traceEvents = [];

  String get _officerName {
    if (widget.username != null && widget.username!.trim().isNotEmpty && widget.username != 'Dr. S. Kumar') {
      return widget.username!;
    }
    final sessionUser = AuthSession.instance.username;
    if (sessionUser != null && sessionUser.trim().isNotEmpty) {
      return sessionUser;
    }
    return 'District Supply Officer';
  }

  @override
  void initState() {
    super.initState();
    _dsoService = DsoService();
    _loadDistricts();
    _loadCommandOverview();
  }

  Future<void> _loadDistricts() async {
    try {
      final districts = await _dsoService.getDistricts();
      if (mounted && districts.isNotEmpty) {
        setState(() {
          _availableDistricts = districts;
          if (!_availableDistricts.contains(_selectedDistrict)) {
            _selectedDistrict = _availableDistricts.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCommandOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overviewData = await _dsoService.getCommandOverview(
        cycleId: _activeCycle,
        district: _selectedDistrict,
      );
      final eventsData = await _dsoService.getGovernanceEvents(cycleId: _activeCycle);

      if (mounted) {
        setState(() {
          _overview = overviewData;
          _traceEvents = eventsData;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _handleSelectNav(int index) {
    if (index == 10) {
      // Toggle Decision Trace Drawer
      setState(() {
        _showTraceDrawer = !_showTraceDrawer;
        _selectedNavIndex = index;
      });
      return;
    }
    if (index == 11) {
      // Open Data Sources Modal
      DsoDataSourceModal.show(
        context,
        title: 'Command Center Database & CSV Datasets',
        datasetName: 'beneficiaries, intent, historical_demand, fps, inventory, depots, vehicles, routes, manifests',
        tableName: 'pds_demandsync.db',
        cycleId: _activeCycle,
        recordCount: '${_overview?.metrics['beneficiaries']?.count.toInt() ?? 10006} beneficiaries',
        formula: 'Real SQLite dataset aggregation & AI pipeline execution',
        apiEndpoint: '/api/v1/admin/dso/command-overview',
      );
      return;
    }

    setState(() {
      _selectedNavIndex = index;
      _showTraceDrawer = false;
    });
  }

  void _showNotificationsDialog() {
    final exceptions = _overview?.exceptions ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text('Operational Notifications (${exceptions.length})'),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: exceptions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No active operational exceptions for this cycle.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: exceptions.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final exc = exceptions[i];
                    return ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: exc.severity == 'CRITICAL' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          exc.severity,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: exc.severity == 'CRITICAL' ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                      title: Text(exc.type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('${exc.fps} • ${exc.details}', style: const TextStyle(fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedNavIndex = 9); // Exceptions page
                        },
                        child: const Text('Resolve', style: TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highSeverityCount = _overview?.exceptions
            .where((e) => e.severity == 'HIGH' || e.severity == 'CRITICAL')
            .length ??
        0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // Left Command Sidebar
          DsoSidebar(
            activeStage: 1,
            selectedNavIndex: _selectedNavIndex,
            onSelectNav: _handleSelectNav,
            exceptionCount: _overview?.exceptions.length ?? 0,
            district: _selectedDistrict,
          ),

          // Main Center Workspace & Right Panel
          Expanded(
            child: Column(
              children: [
                // Top Header
                DsoTopHeader(
                  activeCycle: _activeCycle,
                  selectedDistrict: _selectedDistrict,
                  availableDistricts: _availableDistricts,
                  officerName: _officerName,
                  notificationCount: highSeverityCount,
                  systemStatus: 'Operational',
                  onDistrictChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedDistrict = val);
                      _loadCommandOverview();
                    }
                  },
                  onCycleChanged: (val) {
                    if (val != null) {
                      setState(() => _activeCycle = val);
                      _loadCommandOverview();
                    }
                  },
                  onNotificationsTap: _showNotificationsDialog,
                ),

                // Main Workspace Area
                Expanded(
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Central Content View
                          Expanded(
                            child: _buildCentralWorkspace(),
                          ),

                          // Right AI Panel
                          if (_showAiPanel && _overview != null)
                            DsoAiPanel(
                              aiInsights: _overview!.aiInsights,
                              aiRecommendation: _overview!.aiRecommendation,
                              onClose: () => setState(() => _showAiPanel = false),
                              onViewEvidence: (title, details) {
                                DsoDataSourceModal.show(
                                  context,
                                  title: title,
                                  datasetName: 'DemandSync AI Engine',
                                  tableName: 'forecast / stockout_risk_predictions',
                                  cycleId: _activeCycle,
                                  recordCount: 'Verified against SQLite',
                                  formula: details,
                                  apiEndpoint: '/api/v1/admin/dso/command-overview',
                                );
                              },
                            ),
                        ],
                      ),

                      // Decision Trace Slide-over Drawer
                      if (_showTraceDrawer)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: DsoDecisionTraceDrawer(
                            events: _traceEvents,
                            onClose: () => setState(() => _showTraceDrawer = false),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralWorkspace() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading command overview: $_error', style: const TextStyle(color: Color(0xFFDC2626))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadCommandOverview, child: const Text('Retry Connection')),
          ],
        ),
      );
    }

    switch (_selectedNavIndex) {
      case 0:
      case 1:
        return DsoMonitorView(
          overview: _overview!,
          onNavigateStage: (st) => setState(() => _selectedNavIndex = st),
          onRefresh: _loadCommandOverview,
        );
      case 2:
        return DsoValidateDemandView(
          dsoService: _dsoService,
          cycleId: _activeCycle,
          onValidatedSuccess: _loadCommandOverview,
        );
      case 3:
        return DsoAllocationView(
          dsoService: _dsoService,
          cycleId: _activeCycle,
          onAllocationApproved: _loadCommandOverview,
        );
      case 4:
        return DsoOptimizationView(
          dsoService: _dsoService,
          cycleId: _activeCycle,
          onOptimizationApproved: _loadCommandOverview,
        );
      case 5:
        return DsoDispatchView(
          dsoService: _dsoService,
          cycleId: _activeCycle,
          onDispatchAuthorized: _loadCommandOverview,
        );
      case 6:
        return DsoDeliveryView(
          dsoService: _dsoService,
          cycleId: _activeCycle,
        );
      case 7:
        return DsoEvaluationView(
          dsoService: _dsoService,
          cycleId: _activeCycle,
          onCycleClosed: _loadCommandOverview,
        );
      case 8:
        return _buildAiIntelligenceView();
      case 9:
        return _buildExceptionsView();
      default:
        return DsoMonitorView(
          overview: _overview!,
          onNavigateStage: (st) => setState(() => _selectedNavIndex = st),
          onRefresh: _loadCommandOverview,
        );
    }
  }

  Widget _buildAiIntelligenceView() {
    final insights = _overview?.aiInsights ?? [];
    final rec = _overview?.aiRecommendation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'AI Intelligence Center',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Operational ML inference, demand divergence heuristics, and evidence records',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (rec != null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
              ),
              color: const Color(0xFFF0F9FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Text(
                          'Primary AI Operational Recommendation',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0369A1), fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            rec['confidence'] != null
                                ? 'Confidence: ${rec['confidence']}'
                                : 'Confidence unavailable',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rec['action']?.toString() ?? 'Replenishment Allocation',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rec['rationale']?.toString() ?? '',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Impact: ${rec['impact']?.toString() ?? 'Statutory Fulfillment'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.receipt_long, size: 14),
                          label: const Text('View Evidence', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            DsoDataSourceModal.show(
                              context,
                              title: 'AI Primary Recommendation Evidence',
                              datasetName: 'DemandSync AI Allocation Heuristics',
                              tableName: 'forecast / inventory / fps',
                              cycleId: _activeCycle,
                              recordCount: 'Karnataka PDS Dataset',
                              formula: rec['evidence']?.toString() ?? 'Verified SQLite calculation',
                              apiEndpoint: '/api/v1/admin/dso/command-overview',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          const Text(
            'Active Model Insights & Anomaly Detections',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          if (insights.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text('No anomalous demand or supply insights detected for this cycle.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: insights.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final ins = insights[idx];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ins.severity,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ins.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ins.id.isNotEmpty ? ins.id : 'Model Insight',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(ins.summary, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        Text('Why: ${ins.why}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Evidence: ${ins.evidence.length > 40 ? ins.evidence.substring(0, 40) + '...' : ins.evidence}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.analytics_outlined, size: 14),
                              label: const Text('View Evidence', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                DsoDataSourceModal.show(
                                  context,
                                  title: ins.title,
                                  datasetName: 'AI Demand Inference Engine',
                                  tableName: 'forecast / intent / historical_demand',
                                  cycleId: _activeCycle,
                                  recordCount: 'Verified record in SQLite',
                                  formula: ins.evidence,
                                  apiEndpoint: '/api/v1/admin/dso/command-overview',
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExceptionsView() {
    final allExceptions = _overview?.exceptions ?? [];
    final filtered = _exceptionSeverityFilter == 'ALL'
        ? allExceptions
        : allExceptions.where((e) => e.severity.toUpperCase() == _exceptionSeverityFilter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational Exception Queue (${allExceptions.length} Total)',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Text(
                    'Demand anomalies, stock shortages, delivery variances and statutory operational alerts',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Severity Filter Row
          Row(
            children: [
              const Text('Filter by Severity:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(width: 12),
              _buildFilterChip('ALL', 'All (${allExceptions.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('CRITICAL', 'Critical (${allExceptions.where((e) => e.severity == "CRITICAL").length})'),
              const SizedBox(width: 8),
              _buildFilterChip('HIGH', 'High (${allExceptions.where((e) => e.severity == "HIGH").length})'),
              const SizedBox(width: 8),
              _buildFilterChip('MEDIUM', 'Medium (${allExceptions.where((e) => e.severity == "MEDIUM").length})'),
            ],
          ),
          const SizedBox(height: 16),

          DsoExceptionQueue(
            exceptions: filtered,
            onActionTap: (exc) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Resolve Exception: ${exc.id}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Exception: ${exc.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Entity (FPS): ${exc.fps}'),
                      const SizedBox(height: 4),
                      Text('Type: ${exc.type}'),
                      const SizedBox(height: 4),
                      Text('Severity: ${exc.severity}', style: TextStyle(color: exc.severity == 'CRITICAL' ? Colors.red : Colors.orange)),
                      const SizedBox(height: 8),
                      Text('Details: ${exc.details}'),
                      const SizedBox(height: 12),
                      const Text('Recommended DSO Action:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(exc.action, style: const TextStyle(color: Color(0xFF2563EB))),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('DSO review and action initiated for ${exc.id}')),
                        );
                      },
                      child: const Text('Acknowledge & Action'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String severity, String label) {
    final isSelected = _exceptionSeverityFilter == severity;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _exceptionSeverityFilter = severity);
        }
      },
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
    );
  }
}
