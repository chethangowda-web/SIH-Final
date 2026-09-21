import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/dso/dso_service.dart';
import '../../models/dso/dso_models.dart';
import '../../widgets/dso/dso_sidebar.dart';
import '../../widgets/dso/dso_top_header.dart';
import '../../widgets/dso/dso_ai_panel.dart';
import '../../widgets/dso/dso_decision_trace_drawer.dart';
import '../../widgets/dso/dso_data_source_modal.dart';
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
  bool _showAiPanel = true;
  bool _showTraceDrawer = false;

  bool _loading = true;
  String? _error;
  DsoCommandOverview? _overview;
  List<GovernanceEventItem> _traceEvents = [];

  @override
  void initState() {
    super.initState();
    _dsoService = DsoService();
    _loadCommandOverview();
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

      setState(() {
        _overview = overviewData;
        _traceEvents = eventsData;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // Left Command Sidebar
          DsoSidebar(
            activeStage: 1,
            selectedNavIndex: _selectedNavIndex,
            onSelectNav: _handleSelectNav,
            exceptionCount: _overview?.exceptions.length ?? 7,
          ),

          // Main Center Workspace & Right Panel
          Expanded(
            child: Column(
              children: [
                // Top Header
                DsoTopHeader(
                  activeCycle: _activeCycle,
                  selectedDistrict: _selectedDistrict,
                  officerName: 'Dr. S. Kumar',
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
                  onNotificationsTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('3 high-priority operational notifications active.')),
                    );
                  },
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
      case 9:
      default:
        return DsoMonitorView(
          overview: _overview!,
          onNavigateStage: (st) => setState(() => _selectedNavIndex = st),
          onRefresh: _loadCommandOverview,
        );
    }
  }
}
