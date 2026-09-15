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

  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _amber = Color(0xFFD97706);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);

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
        _inspectionsOrders = (insp['orders'] as List<dynamic>? ?? []).map((o) => Map<String, dynamic>.from(o as Map)).toList();
        _completedInspections = (insp['completed_inspections'] as List<dynamic>? ?? []).map((o) => Map<String, dynamic>.from(o as Map)).toList();
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showIssueSurpriseInspectionModal() {
    String selectedFps = _fpsList.isNotEmpty ? _fpsList.first.fpsId : 'FPS-KA-BAG-0001';
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
                    'Select Target Fair Price Shop (Search 625 Dataset):',
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
                        value: filteredList.any((f) => f.fpsId == selectedFps) ? selectedFps : (filteredList.isNotEmpty ? filteredList.first.fpsId : null),
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
                            content: Text('⚡ Surprise Inspection Order issued for $selectedFps! Alert dispatched to Field Food Inspector.'),
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
                    // DSO Action Header Bar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _slate200),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFF0FDF4),
                            radius: 20,
                            child: Icon(Icons.account_balance_outlined, color: _govGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('District Operational Authority Console', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _slate900)),
                                Text('Operate pre-dispatch quotas, issue surprise inspections, and review field inspector submissions.', style: TextStyle(fontSize: 11.5, color: _slate500)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showIssueSurpriseInspectionModal,
                            icon: const Icon(Icons.emergency_outlined, size: 16),
                            label: const Text('Issue Surprise Inspection Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _dangerRed,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. High-Level District Metrics Cards
                    const Text('1. High-Level District Demand Overview:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
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
                          const SizedBox(height: 16),

                          // 2. Total District Grain Charts Section
                          const Text('2. Total District Grain Distribution & Demand Trends:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
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
                    }),
                    const SizedBox(height: 16),

                    // 3. Active Surprise Inspection Orders & Reports Monitor
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('3. Active Directives & Field Inspection Reports:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
                        Text('${_inspectionsOrders.length} Total Orders', style: const TextStyle(fontSize: 11, color: _slate500)),
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
                                      Text(o['fps_id'] ?? 'FPS-KA-0001', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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
                ),
              ),
            ),
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
