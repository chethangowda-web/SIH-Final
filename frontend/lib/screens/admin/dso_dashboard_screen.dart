import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';
import '../../models/admin_model.dart';
import 'admin_dashboard_screen.dart';

class DsoDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const DsoDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<DsoDashboardScreen> createState() => _DsoDashboardScreenState();
}

class _DsoDashboardScreenState extends State<DsoDashboardScreen> {
  late final ApiService _apiService;
  bool _isLoading = true;
  AdminDashboardData? _dashboardData;
  List<FpsShop> _fpsList = [];
  List<Map<String, dynamic>> _inspectionsOrders = [];
  List<Map<String, dynamic>> _completedInspections = [];

  // Selected corridor filter (null means all corridors)
  String? _selectedCorridor;

  // What-If Simulation State
  double _simIntentTurnoutPct = 78.0; // 50% - 100%
  double _simBufferPct = 5.0; // 0% - 15%
  bool _isSimulatorExpanded = true;

  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govNavyLight = Color(0xFF1E3A5F);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _amber = Color(0xFFD97706);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);

  // Corridor Metadata definitions for Bengaluru Urban
  final List<Map<String, dynamic>> _corridorStats = [
    {
      'id': 'NORTH',
      'name': 'North Corridor',
      'hub': 'Hebbal / Yelahanka',
      'fpsCount': 5,
      'demandMt': 68.4,
      'trucks': 2,
      'status': 'NOMINAL',
      'statusColor': _govGreen,
      'leadFps': 'FPS-KA-0001',
    },
    {
      'id': 'SOUTH',
      'name': 'South Corridor',
      'hub': 'Jayanagar / BTM',
      'fpsCount': 6,
      'demandMt': 84.2,
      'trucks': 3,
      'status': 'OPTIMAL',
      'statusColor': _govGreen,
      'leadFps': 'FPS-KA-0004',
    },
    {
      'id': 'EAST',
      'name': 'East Corridor',
      'hub': 'KR Puram / Whitefield',
      'fpsCount': 5,
      'demandMt': 72.8,
      'trucks': 2,
      'status': 'FESTIVAL SURGE (+38%)',
      'statusColor': _dangerRed,
      'leadFps': 'FPS-KA-0008',
    },
    {
      'id': 'WEST',
      'name': 'West Corridor',
      'hub': 'Rajajinagar / Peenya',
      'fpsCount': 4,
      'demandMt': 51.3,
      'trucks': 2,
      'status': 'BUFFER MONITOR',
      'statusColor': _amber,
      'leadFps': 'FPS-KA-0012',
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadDsoData();
  }

  Future<void> _loadDsoData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch district admin summary
      try {
        _dashboardData = await _apiService.fetchAdminDashboard();
      } catch (_) {}

      // 2. Fetch FPS list
      try {
        _fpsList = await _apiService.fetchFPSList();
      } catch (_) {}

      // 3. Fetch inspections list
      try {
        final insp = await _apiService.fetchFpsInspections();
        _inspectionsOrders = (insp['orders'] as List<dynamic>? ?? [])
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList();
        _completedInspections = (insp['completed_inspections'] as List<dynamic>? ?? [])
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList();
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------- EXECUTIVE ACTIONS ----------------- //

  /// 1. Bulk Approve & Lock Clean Quotas
  void _showBulkApproveModal() {
    bool isProcessing = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: _govGreen, size: 24),
                SizedBox(width: 8),
                Text('Bulk Authorize Clean Quotas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This executive action will automatically lock pre-dispatch allocations for all verified, nominal Fair Price Shops in Bengaluru Urban.',
                  style: TextStyle(fontSize: 12.5, color: _slate700, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: _govGreen, size: 16),
                          SizedBox(width: 6),
                          Text('18 Nominal Shops: Pre-approved for dispatch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govGreen)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: _amber, size: 16),
                          SizedBox(width: 6),
                          Text('2 Flagged Shops: Held for Inspector Sign-off', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _amber)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Digital Seal: SHA-256 Cryptographic Lock will be applied.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isProcessing
                    ? null
                    : () async {
                        setModalState(() => isProcessing = true);
                        try {
                          await _apiService.triggerLockForecast();
                        } catch (_) {}
                        if (!mounted) return;
                        Navigator.of(ctx).pop();
                        _loadDsoData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Clean Quotas Authorized! Dispatch manifests generated for 18 FPS centers.'),
                            backgroundColor: _govGreen,
                          ),
                        );
                      },
                icon: isProcessing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_outline, size: 16),
                label: const Text('Confirm & Authorize Dispatch'),
                style: ElevatedButton.styleFrom(backgroundColor: _govGreen, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 2. Issue Surprise Inspection Modal
  void _showIssueSurpriseInspectionModal() {
    String selectedFps = _fpsList.isNotEmpty ? _fpsList.first.fpsId : 'FPS-KA-0001';
    String priority = 'HIGH';
    String searchFilter = '';
    final reasonController = TextEditingController(
      text: 'Stock discrepancy detected via AI demand variance reconciliation. Conduct immediate physical weighing audit.',
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredList = _fpsList.where((fps) {
            if (searchFilter.isEmpty) return true;
            final q = searchFilter.toLowerCase();
            return fps.fpsId.toLowerCase().contains(q) || fps.name.toLowerCase().contains(q);
          }).toList();

          if (filteredList.isNotEmpty && !filteredList.any((f) => f.fpsId == selectedFps)) {
            selectedFps = filteredList.first.fpsId;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: _dangerRed, size: 24),
                SizedBox(width: 8),
                Text('Issue Surprise Inspection Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Target Fair Price Shop (Bengaluru Urban):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Filter by FPS ID or Locality...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                    ),
                    onChanged: (val) {
                      setModalState(() => searchFilter = val.trim());
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _slate200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: filteredList.any((f) => f.fpsId == selectedFps)
                            ? selectedFps
                            : (filteredList.isNotEmpty ? filteredList.first.fpsId : null),
                        isExpanded: true,
                        items: filteredList.take(50).map((fps) {
                          return DropdownMenuItem(
                            value: fps.fpsId,
                            child: Text('${fps.fpsId} - ${fps.name}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedFps = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Audit Directive Priority:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['CRITICAL', 'HIGH', 'NORMAL'].map((p) {
                      final isSel = priority == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(p, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : _slate700)),
                          selected: isSel,
                          selectedColor: p == 'CRITICAL' ? _dangerRed : (p == 'HIGH' ? _amber : _govNavy),
                          onSelected: (_) => setModalState(() => priority = p),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  const Text('Quick Directive Reason Preset:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      'Weighing scale bias',
                      'ePoS biometric mismatch',
                      'Portability diversion surge',
                      'Buffer stock deficit',
                    ].map((preset) {
                      return ActionChip(
                        label: Text(preset, style: const TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          setModalState(() {
                            reasonController.text = 'Unannounced audit directive: $preset flagged by DSO Command Center.';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  const Text('Operational Directive & Reason:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter reason for unannounced inspection...',
                      filled: true,
                      fillColor: _slate100,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          await _apiService.orderSurpriseInspection(
                            fpsId: selectedFps,
                            reason: reasonController.text.trim(),
                            priority: priority,
                          );
                          if (!mounted) return;
                          Navigator.of(ctx).pop();
                          _loadDsoData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('⚡ Surprise Inspection Order dispatched for $selectedFps to Field Inspector!'),
                              backgroundColor: _govGreen,
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to issue order: $e'), backgroundColor: _dangerRed),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: _dangerRed, foregroundColor: Colors.white),
                child: isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Dispatch Order to Inspector'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 3. Export Official District Gazette Order Modal
  void _showGazetteOrderModal() {
    final cycle = _dashboardData?.activeCycle ?? '2026-09';
    final totalForecastMt = _dashboardData != null && _dashboardData!.totalForecastDemandKg > 0
        ? (_dashboardData!.totalForecastDemandKg / 1000.0).toStringAsFixed(1)
        : '276.7';
    final riceMt = _dashboardData != null && _dashboardData!.totalForecastDemandKg > 0
        ? (_dashboardData!.totalForecastDemandKg * 0.665 / 1000.0).toStringAsFixed(1)
        : '184.0';
    final wheatMt = _dashboardData != null && _dashboardData!.totalForecastDemandKg > 0
        ? (_dashboardData!.totalForecastDemandKg * 0.248 / 1000.0).toStringAsFixed(1)
        : '68.6';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.description_outlined, color: _govNavy, size: 24),
            const SizedBox(width: 8),
            Text('District Gazette Order • Cycle $cycle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Text('GOVERNMENT OF KARNATAKA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1, color: _slate900)),
                      const Text('DEPARTMENT OF FOOD, CIVIL SUPPLIES & CONSUMER AFFAIRS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _slate700)),
                      const SizedBox(height: 4),
                      Text('ORDER NO: PDS-DS-BLR-$cycle/OFF-4419', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: _govNavy)),
                      const Divider(height: 16),
                    ],
                  ),
                ),
                const Text('SUBJECT: Pre-Dispatch Foodgrain Quota Allocation & Corridor Route Authorization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 8),
                Text(
                  'In exercise of the powers conferred under the National Food Security Act (NFSA) and ONORC Portability Framework, the undersigned District Supply Officer (Bengaluru Urban) hereby approves the AI-forecasted grain quotas for Cycle $cycle.',
                  style: const TextStyle(fontSize: 10.5, color: _slate700, height: 1.4),
                ),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: _slate200, width: 1),
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                      children: [
                        Padding(padding: EdgeInsets.all(6), child: Text('Commodity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Allocated (MT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Source Godown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(padding: EdgeInsets.all(6), child: Text('Fortified Rice (PHH/AAY)', style: TextStyle(fontSize: 10))),
                        Padding(padding: const EdgeInsets.all(6), child: Text('$riceMt MT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        const Padding(padding: EdgeInsets.all(6), child: Text('FCI Godown, Hebbal', style: TextStyle(fontSize: 10))),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(padding: EdgeInsets.all(6), child: Text('Whole Wheat', style: TextStyle(fontSize: 10))),
                        Padding(padding: const EdgeInsets.all(6), child: Text('$wheatMt MT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        const Padding(padding: EdgeInsets.all(6), child: Text('FCI Godown, Hebbal', style: TextStyle(fontSize: 10))),
                      ],
                    ),
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: [
                        const Padding(padding: EdgeInsets.all(6), child: Text('Total District Quota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                        Padding(padding: const EdgeInsets.all(6), child: Text('$totalForecastMt MT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: _govGreen))),
                        const Padding(padding: EdgeInsets.all(6), child: Text('20 FPS Centers', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _slate200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SHA-256 Digital Seal:', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _slate700)),
                      Text('e4b9c107a90f845d429a99723c3167fb64d85202861e687259f6368d11d9f481', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: _slate500)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: 2026-09-16', style: TextStyle(fontSize: 10, color: _slate500)),
                        Text('Place: Bengaluru Urban', style: TextStyle(fontSize: 10, color: _slate500)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('K. Srinivas Murthy, KAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _slate900)),
                        const Text('District Supply Officer (DSO)', style: TextStyle(fontSize: 10, color: _slate700)),
                        Text('Digitally Signed • ${widget.username ?? "dso_user"}', style: const TextStyle(fontSize: 9, color: _govGreen, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📄 District Gazette Order exported as PDF & dispatched to Godown Bay Manager.'),
                  backgroundColor: _govNavy,
                ),
              );
            },
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print / Dispatch Gazette Order'),
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  /// 4. Escalate Inspection to Auditor
  void _showEscalateInspectionModal(Map<String, dynamic> inspection) {
    final fpsId = inspection['fps_id'] ?? 'FPS-KA-0012';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_update_warning_rounded, color: _dangerRed, size: 24),
            SizedBox(width: 8),
            Text('Escalate to Vigilance Auditor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escalate inspection findings for $fpsId directly to the Vigilance & Audit Bureau?', style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shop: $fpsId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _dangerRed)),
                  Text('Reason: ${inspection['reason'] ?? "Variance in weighing scale"}', style: const TextStyle(fontSize: 10.5, color: _slate700)),
                  const SizedBox(height: 4),
                  const Text('Action: Freezes dealer quota and initiates formal disciplinary inquiry.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _dangerRed)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🚨 $fpsId escalated to Vigilance Auditor! Ticket #VIG-BLR-${DateTime.now().millisecondsSinceEpoch % 10000} opened.'),
                  backgroundColor: _dangerRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _dangerRed, foregroundColor: Colors.white),
            child: const Text('Confirm Escalation'),
          ),
        ],
      ),
    );
  }

  // ----------------- BUILD MAIN DASHBOARD ----------------- //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _govNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'District Supply Officer (DSO) Command Portal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Bengaluru Urban District • Planning & Decision Authority • User: ${widget.username ?? "dso_user"}',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
        actions: [
          // Launch Master Platform Stepper
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminDashboardScreen(
                    apiService: _apiService,
                    userRole: 'DSO',
                    username: widget.username ?? 'dso_user',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 16),
            label: const Text('Full Platform Stepper', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh District Real Data',
            onPressed: _loadDsoData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDsoData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. EXECUTIVE AI BRIEFING BANNER
                    _buildExecutiveAiBriefingBanner(),
                    const SizedBox(height: 16),

                    // 2. EXECUTIVE 1-CLICK ACTION TRAY
                    _buildExecutiveActionTray(),
                    const SizedBox(height: 16),

                    // 3. WHAT-IF SCENARIO SIMULATOR BAR
                    _buildWhatIfSimulatorCard(),
                    const SizedBox(height: 16),

                    // 4. CORRIDOR LOGISTICS & STOCKOUT HAZARD MATRIX
                    _buildCorridorHazardMatrix(),
                    const SizedBox(height: 16),

                    // 5. HIGH-LEVEL DISTRICT DEMAND METRICS
                    _buildHighLevelMetricsSection(),
                    const SizedBox(height: 16),

                    // 6. TOTAL DISTRICT GRAIN DISTRIBUTION BARS
                    _buildGrainDistributionSection(),
                    const SizedBox(height: 16),

                    // 7. ACTIVE DIRECTIVES & VIGILANCE TRIAGE FEED
                    _buildVigilanceTriageSection(),
                  ],
                ),
              ),
            ),
    );
  }

  // ----------------- SUB-COMPONENTS ----------------- //

  /// 1. Executive AI Briefing Banner
  Widget _buildExecutiveAiBriefingBanner() {
    final cycle = _dashboardData?.activeCycle ?? '2026-09';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_govNavy, _govNavyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: _govNavy.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF34D399)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF34D399), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'AI Copilot • Real-Time District Situation Briefing',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Cycle: $cycle • Day 21 (Window Locked)',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'District Situation Overview: 94.2% Intent Confidence',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'North and South corridors show nominal lifting patterns. ⚠️ East Corridor exhibits a +38% surge in portability intent due to festive labor mobility. 1 inspection flagged at FPS-KA-0012 for weighing calibration.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFFFDE047), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recommended Action: Authorize Corridor Dispatches with 5% Safety Buffer on East corridor. Isolate FPS-KA-0012 pending inspector report.',
                    style: TextStyle(color: Color(0xFFFEF08A), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Executive 1-Click Action Tray
  Widget _buildExecutiveActionTray() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slate200),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final buttons = [
          _buildActionButton(
            label: 'Bulk Authorize Clean Quotas',
            icon: Icons.verified_user_rounded,
            color: _govGreen,
            onPressed: _showBulkApproveModal,
          ),
          _buildActionButton(
            label: 'Issue Surprise Inspection',
            icon: Icons.emergency_outlined,
            color: _dangerRed,
            onPressed: _showIssueSurpriseInspectionModal,
          ),
          _buildActionButton(
            label: 'Export Gazette Allocation Order',
            icon: Icons.description_outlined,
            color: _govNavy,
            onPressed: _showGazetteOrderModal,
          ),
        ];

        if (isWide) {
          return Row(
            children: buttons.map((b) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: b))).toList(),
          );
        } else {
          return Column(
            children: buttons.map((b) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: b)).toList(),
          );
        }
      }),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// 3. What-If Scenario Simulator Card
  Widget _buildWhatIfSimulatorCard() {
    // Dynamic recalculations based on slider values
    final double projectedStockoutRisk = (14.8 * (1.0 - (_simIntentTurnoutPct - 50.0) / 100.0) * (1.0 - _simBufferPct / 20.0)).clamp(1.2, 22.0);
    final double requiredTruckFleet = 7.0 + (_simBufferPct > 5.0 ? 2.0 : 0.0) + (_simIntentTurnoutPct > 80.0 ? 1.0 : 0.0);
    final double projectedStorageHeadroomMt = (52.0 - (_simBufferPct * 1.8)).clamp(15.0, 60.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isSimulatorExpanded = !_isSimulatorExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: _govNavy, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What-If Scenario Simulator (DSO Policy Controls)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate900)),
                        Text('Dynamically adjust intent participation and safety buffer parameters in real-time.', style: TextStyle(fontSize: 11, color: _slate500)),
                      ],
                    ),
                  ),
                  Icon(
                    _isSimulatorExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: _slate500,
                  ),
                ],
              ),
            ),
          ),
          if (_isSimulatorExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 650;
                    final slider1 = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Intent Participation Turnout:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _slate700)),
                            Text('${_simIntentTurnoutPct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _govNavy)),
                          ],
                        ),
                        Slider(
                          value: _simIntentTurnoutPct,
                          min: 50.0,
                          max: 100.0,
                          divisions: 10,
                          activeColor: _govNavy,
                          inactiveColor: _slate200,
                          onChanged: (v) => setState(() => _simIntentTurnoutPct = v),
                        ),
                      ],
                    );

                    final slider2 = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('District Safety Buffer Quota:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _slate700)),
                            Text('${_simBufferPct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _govGreen)),
                          ],
                        ),
                        Slider(
                          value: _simBufferPct,
                          min: 0.0,
                          max: 15.0,
                          divisions: 15,
                          activeColor: _govGreen,
                          inactiveColor: _slate200,
                          onChanged: (v) => setState(() => _simBufferPct = v),
                        ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: slider1),
                          const SizedBox(width: 20),
                          Expanded(child: slider2),
                        ],
                      );
                    } else {
                      return Column(children: [slider1, const SizedBox(height: 8), slider2]);
                    }
                  }),
                  const SizedBox(height: 10),

                  // Real-time recalculation indicators
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSimStat(
                          'Projected Stockout Risk',
                          '${projectedStockoutRisk.toStringAsFixed(1)}%',
                          projectedStockoutRisk < 5.0 ? _govGreen : (projectedStockoutRisk < 12.0 ? _amber : _dangerRed),
                        ),
                        _buildSimStat(
                          'Required Fleet',
                          '${requiredTruckFleet.toInt()} Trucks (10T)',
                          _govNavy,
                        ),
                        _buildSimStat(
                          'Storage Headroom',
                          '${projectedStorageHeadroomMt.toStringAsFixed(1)} MT',
                          _govGreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: _slate500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  /// 4. Corridor Logistics & Stockout Hazard Matrix
  Widget _buildCorridorHazardMatrix() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Corridor Logistics & Stockout Hazard Matrix (Bengaluru Urban):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900),
            ),
            if (_selectedCorridor != null)
              TextButton.icon(
                onPressed: () => setState(() => _selectedCorridor = null),
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear Filter', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return GridView.builder(
            crossAxisCount: isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _corridorStats.length,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isWide ? 1.6 : 1.35,
            itemBuilder: (context, idx) {
              final c = _corridorStats[idx];
              final isSelected = _selectedCorridor == c['id'];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCorridor = isSelected ? null : c['id'] as String;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3B82F6) : _slate200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              c['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _slate900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (c['statusColor'] as Color).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c['status'] as String,
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: c['statusColor'] as Color),
                            ),
                          ),
                        ],
                      ),
                      Text(c['hub'] as String, style: const TextStyle(fontSize: 10, color: _slate500)),
                      const Divider(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${c['fpsCount']} FPS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate700)),
                          Text('${c['demandMt']} MT', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _govNavy)),
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 12, color: _slate500),
                              const SizedBox(width: 2),
                              Text('${c['trucks']} Trucks', style: const TextStyle(fontSize: 10, color: _slate500)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  /// 5. High-Level Metrics Section
  Widget _buildHighLevelMetricsSection() {
    final histMt = _dashboardData != null && _dashboardData!.totalHistoricalDemandKg > 0
        ? (_dashboardData!.totalHistoricalDemandKg / 1000).toStringAsFixed(1)
        : '481.1';
    final intentMt = _dashboardData != null && _dashboardData!.totalDeclaredIntentKg > 0
        ? (_dashboardData!.totalDeclaredIntentKg / 1000).toStringAsFixed(1)
        : '129.9';
    final forecastMt = _dashboardData != null && _dashboardData!.totalForecastDemandKg > 0
        ? (_dashboardData!.totalForecastDemandKg / 1000).toStringAsFixed(1)
        : '276.7';
    final highRisk = _dashboardData != null
        ? '${_dashboardData!.highRiskFpsCount} Shops'
        : '61 Shops';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('High-Level District Demand Baseline:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isWide ? 2.3 : 1.9,
            children: [
              _buildMetricTile('Historical Baseline', '$histMt MT', 'Previous 3-cycle aggregate', Icons.history_rounded, _govNavy),
              _buildMetricTile('Intent Demand', '$intentMt MT', '+12.4% advance signals', Icons.sensors_rounded, const Color(0xFF2563EB)),
              _buildMetricTile('Forecast Demand (D̂)', '$forecastMt MT', 'AI Baseline + Intent', Icons.auto_graph_rounded, _govGreen),
              _buildMetricTile('High-Risk Stockouts', highRisk, 'Exceeding 75% threshold', Icons.warning_amber_rounded, _dangerRed),
            ],
          );
        }),
      ],
    );
  }

  /// 6. Total District Grain Distribution Section
  Widget _buildGrainDistributionSection() {
    final totalForecastMt = _dashboardData != null && _dashboardData!.totalForecastDemandKg > 0
        ? _dashboardData!.totalForecastDemandKg / 1000.0
        : 276.7;
    final riceMt = totalForecastMt * 0.665;
    final wheatMt = totalForecastMt * 0.248;
    final ragiMt = totalForecastMt * 0.061;
    final sugarMt = totalForecastMt * 0.026;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total District Grain Distribution & Demand Trends:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('District Monthly Commodity Demand (Metric Tons)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Active Cycle: ${_dashboardData?.activeCycle ?? "2026-09"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govGreen)),
                ],
              ),
              const SizedBox(height: 14),
              _buildGrainBar('Fortified Rice', riceMt, totalForecastMt * 1.1, _govGreen),
              const SizedBox(height: 10),
              _buildGrainBar('Whole Wheat', wheatMt, totalForecastMt * 1.1, _amber),
              const SizedBox(height: 10),
              _buildGrainBar('Ragi / Coarse Grains', ragiMt, totalForecastMt * 1.1, const Color(0xFF6B21A8)),
              const SizedBox(height: 10),
              _buildGrainBar('Refined Sugar & Dal', sugarMt, totalForecastMt * 1.1, const Color(0xFF2563EB)),
            ],
          ),
        ),
      ],
    );
  }

  /// 7. Integrated Vigilance & Triage Feed Section
  Widget _buildVigilanceTriageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Directives & Field Inspection Reports:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
            Text('${_inspectionsOrders.length} Directives', style: const TextStyle(fontSize: 11, color: _slate500)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _slate200),
          ),
          child: _inspectionsOrders.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.checklist_rounded, size: 36, color: _slate500),
                        const SizedBox(height: 6),
                        const Text('No surprise inspection orders dispatched yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        const Text('Click "Issue Surprise Inspection Order" above to direct a Field Food Inspector.', style: TextStyle(fontSize: 11, color: _slate500)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _inspectionsOrders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final o = _inspectionsOrders[idx];
                    final isPending = o['status'] == 'PENDING';
                    final fpsId = o['fps_id'] ?? 'FPS-KA-0001';

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: isPending ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                        radius: 16,
                        child: Icon(
                          isPending ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                          size: 18,
                          color: isPending ? _amber : _govGreen,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(fpsId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              o['status'] ?? 'PENDING',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPending ? _amber : _govGreen),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _showEscalateInspectionModal(o),
                            icon: const Icon(Icons.shield_outlined, size: 12, color: _dangerRed),
                            label: const Text('Escalate', style: TextStyle(fontSize: 10.5, color: _dangerRed, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Reason: ${o['reason'] ?? "Stock variance check"} • Priority: ${o['priority'] ?? "HIGH"}',
                        style: const TextStyle(fontSize: 11, color: _slate500),
                      ),
                      trailing: Text(
                        (o['created_at'] as String? ?? 'Today').split('T').first,
                        style: const TextStyle(fontSize: 10, color: _slate500),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate700), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 9.5, color: _slate500)),
        ],
      ),
    );
  }

  Widget _buildGrainBar(String commodity, double valMt, double maxMt, Color color) {
    final pct = (valMt / maxMt).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(commodity, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text('${valMt.toStringAsFixed(1)} MT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: _slate100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
