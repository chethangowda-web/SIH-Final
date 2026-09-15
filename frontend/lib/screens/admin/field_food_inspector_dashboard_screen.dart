import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';

class FieldFoodInspectorDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const FieldFoodInspectorDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<FieldFoodInspectorDashboardScreen> createState() => _FieldFoodInspectorDashboardScreenState();
}

class _FieldFoodInspectorDashboardScreenState extends State<FieldFoodInspectorDashboardScreen> {
  late final ApiService _apiService;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Real FPS List from backend
  List<FpsShop> _fpsList = [];
  String _searchQuery = '';
  String _selectedFpsId = 'FPS-KA-BAG-0001';
  FpsShop? _selectedFps;

  // Real DSO Surprise Directives from backend
  List<Map<String, dynamic>> _surpriseOrders = [];
  String? _selectedOrderId;

  // 6-Point Digital Audit Checklist
  bool _scaleCertified = true;
  bool _displayBoardUpdated = true;
  bool _stockMatchesRegister = true;
  bool _cctvFunctional = true;
  bool _eposOnline = true;
  bool _hygieneCompliant = true;

  final TextEditingController _remarksController = TextEditingController(
    text: 'All physical grain sacks weighed and inspected. Electronic weighing machine calibrated within ±0.05% tolerance. No stock diversion detected.',
  );

  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _amberAlert = Color(0xFFD97706);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadInspectorData();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadInspectorData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch real FPS list from backend
      try {
        final fpsList = await _apiService.fetchFPSList();
        if (fpsList.isNotEmpty) {
          _fpsList = fpsList;
          _selectedFps = _fpsList.firstWhere(
            (f) => f.fpsId == _selectedFpsId,
            orElse: () => _fpsList.first,
          );
          _selectedFpsId = _selectedFps!.fpsId;
        }
      } catch (_) {}

      // 2. Fetch real surprise inspection orders from DSO
      try {
        final inspData = await _apiService.fetchFpsInspections();
        final orders = inspData['orders'] as List<dynamic>? ?? [];
        _surpriseOrders = orders.map((o) => Map<String, dynamic>.from(o as Map)).toList();

        // If there is an active pending order, auto-highlight it
        final pendingOrder = _surpriseOrders.firstWhere(
          (o) => o['status'] == 'PENDING',
          orElse: () => {},
        );
        if (pendingOrder.isNotEmpty) {
          _selectedOrderId = pendingOrder['order_id'] as String?;
          final targetFps = pendingOrder['fps_id'] as String?;
          if (targetFps != null && targetFps.isNotEmpty) {
            _selectedFpsId = targetFps;
            if (_fpsList.isNotEmpty) {
              _selectedFps = _fpsList.firstWhere(
                (f) => f.fpsId == _selectedFpsId,
                orElse: () => _fpsList.first,
              );
            }
          }
        }
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _complianceScore {
    int passed = 0;
    if (_scaleCertified) passed++;
    if (_displayBoardUpdated) passed++;
    if (_stockMatchesRegister) passed++;
    if (_cctvFunctional) passed++;
    if (_eposOnline) passed++;
    if (_hygieneCompliant) passed++;
    return (passed / 6.0) * 100.0;
  }

  Future<void> _handleSubmitReport() async {
    setState(() => _isSubmitting = true);
    final score = _complianceScore;

    try {
      final res = await _apiService.submitFpsInspectionReport(
        fpsId: _selectedFpsId,
        orderId: _selectedOrderId,
        scaleCertified: _scaleCertified,
        displayBoardUpdated: _displayBoardUpdated,
        stockMatchesRegister: _stockMatchesRegister,
        cctvFunctional: _cctvFunctional,
        eposOnline: _eposOnline,
        hygieneCompliant: _hygieneCompliant,
        complianceScore: score,
        remarks: _remarksController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final inspectionId = res['inspection_id'] ?? 'INSP-OK';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: _govGreen, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Official Report Submitted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Physical inspection permanently sealed in central PDS compliance ledger.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Inspection ID:', style: TextStyle(fontSize: 12, color: _slate500)),
                        Text(inspectionId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _slate900)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fair Price Shop:', style: TextStyle(fontSize: 12, color: _slate500)),
                        Text(_selectedFpsId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _slate900)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Compliance Score:', style: TextStyle(fontSize: 12, color: _slate500)),
                        Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: score >= 80 ? _govGreen : _amberAlert)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _loadInspectorData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _govNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Acknowledge & Refresh'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit inspection report: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  List<FpsShop> get _filteredFpsList {
    if (_searchQuery.isEmpty) return _fpsList;
    final q = _searchQuery.toLowerCase();
    return _fpsList.where((f) => f.fpsId.toLowerCase().contains(q) || f.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingOrders = _surpriseOrders.where((o) => o['status'] == 'PENDING').toList();

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
              'Field Food Inspector Portal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Officer: ${widget.username ?? "inspector_user"} • Assigned Zone: Bengaluru Urban • Food & Civil Supplies',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Real Data',
            onPressed: _loadInspectorData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInspectorData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DSO Active Directive Banner
                    if (pendingOrders.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: _amberAlert, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'DSO Directive: ${pendingOrders.length} Surprise Inspection Order(s) Active',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...pendingOrders.map((order) {
                              final isCurrent = _selectedOrderId == order['order_id'];
                              return Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xFFFEF3C7) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isCurrent ? _amberAlert : _slate200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Shop: ${order['fps_id']} • Priority: ${order['priority'] ?? "HIGH"}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          Text(
                                            'Reason: ${order['reason'] ?? "Stock variance investigation"}',
                                            style: const TextStyle(fontSize: 11, color: _slate700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedOrderId = order['order_id'] as String?;
                                          _selectedFpsId = order['fps_id'] as String? ?? _selectedFpsId;
                                          if (_fpsList.isNotEmpty) {
                                            _selectedFps = _fpsList.firstWhere(
                                              (f) => f.fpsId == _selectedFpsId,
                                              orElse: () => _fpsList.first,
                                            );
                                          }
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isCurrent ? _govNavy : _amberAlert,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: Text(isCurrent ? 'Selected' : 'Inspect Now', style: const TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // 1. Assigned Ration Shops Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '1. Select Assigned Ration Shop (From Master Dataset):',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900),
                        ),
                        Text(
                          '${_fpsList.length} Total Shops',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Search Filter
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search by FPS ID or Area (e.g. FPS-KA-BAG-0001, Malleshwaram)...',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Shop List Selection
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _slate200),
                      ),
                      child: _filteredFpsList.isEmpty
                          ? const Center(child: Text('No matching Fair Price Shops found', style: TextStyle(fontSize: 12, color: _slate500)))
                          : ListView.separated(
                              itemCount: _filteredFpsList.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final fps = _filteredFpsList[idx];
                                final isSelected = fps.fpsId == _selectedFpsId;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: const Color(0xFFF0FDF4),
                                  leading: Icon(
                                    Icons.storefront_outlined,
                                    size: 18,
                                    color: isSelected ? _govGreen : _slate500,
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        fps.name,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? _govGreen : _slate900,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _slate100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(fps.fpsId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate700)),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${fps.district} • Capacity: ${fps.capacityKg.toStringAsFixed(0)} kg • Current Stock: ${fps.currentInventoryTotalKg.toStringAsFixed(0)} kg',
                                    style: const TextStyle(fontSize: 11, color: _slate500),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, size: 16, color: _govGreen)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedFpsId = fps.fpsId;
                                      _selectedFps = fps;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Digital Checklist Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '2. 6-Point Digital Audit Checklist:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _complianceScore >= 80 ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _complianceScore >= 80 ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            'Score: ${_complianceScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _complianceScore >= 80 ? _govGreen : _amberAlert,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _slate200),
                      ),
                      child: Column(
                        children: [
                          _buildChecklistTile('1. Weigher Scale Electronic Calibration Certificate Valid', 'Tolerance verified within ±0.05%', _scaleCertified, (v) => setState(() => _scaleCertified = v)),
                          const Divider(height: 1),
                          _buildChecklistTile('2. Daily Statutory Stock Board Display Updated Outside Shop', 'Prices and stock quantities legible to citizens', _displayBoardUpdated, (v) => setState(() => _displayBoardUpdated = v)),
                          const Divider(height: 1),
                          _buildChecklistTile('3. Sample Grain Quality Verification (Moisture < 12%)', 'Fortified rice & whole wheat free from insect infestation', _stockMatchesRegister, (v) => setState(() => _stockMatchesRegister = v)),
                          const Divider(height: 1),
                          _buildChecklistTile('4. CCTV Security Recording Feed Active & Stored', '30-day retention verified for shop entrance & weighing scale', _cctvFunctional, (v) => setState(() => _cctvFunctional = v)),
                          const Divider(height: 1),
                          _buildChecklistTile('5. Biometric e-PoS Terminal Responsive & Online', '4G/Wi-Fi connected and biometric reader clean', _eposOnline, (v) => setState(() => _eposOnline = v)),
                          const Divider(height: 1),
                          _buildChecklistTile('6. Physical Register vs e-PoS Ledger Audit Aligned', 'Zero unaccounted stock variance detected', _hygieneCompliant, (v) => setState(() => _hygieneCompliant = v)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Inspector Remarks & Submit Section
                    const Text(
                      '3. Inspector Remarks & Audit Findings:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _remarksController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Enter field observations, weighing machine serial number, or variance notes...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _govGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SUBMIT OFFICIAL INSPECTION REPORT FOR ${_selectedFpsId}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildChecklistTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: _govGreen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      title: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: value ? _slate900 : _slate500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: _slate500)),
    );
  }
}
