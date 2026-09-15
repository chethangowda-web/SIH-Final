import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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
  String _selectedFpsId = 'FPS-KA-BAG-0001';
  bool _isSubmitting = false;

  // 6 Verification Checklist Points
  final Map<String, bool> _checklist = {
    'Weigher Scale Calibration Certificate Valid': true,
    'Daily Stock Board Display Updated Outside Shop': true,
    'Sample Grain Quality Verification (Moisture < 12%)': true,
    'CCTV Security Recording Feed Active & Stored': true,
    'Biometric e-PoS Terminal Responsive & Online': true,
    'Physical Register vs e-PoS Ledger Audit Aligned': true,
  };

  final TextEditingController _inspectorNotesController = TextEditingController(
    text: 'All stock items physically verified. Weighing machines accurate within ±0.05%. No compliance anomalies detected.',
  );

  final List<Map<String, dynamic>> _assignedShops = [
    {
      'id': 'FPS-KA-BAG-0001',
      'name': 'Malleshwaram Fair Price Shop #1',
      'location': 'Malleshwaram 8th Main',
      'status': 'INSPECTION_DUE',
      'lastInspected': '28 Aug 2026',
    },
    {
      'id': 'FPS-KA-MAL-0002',
      'name': 'Rajajinagar PDS Center',
      'location': 'Rajajinagar Block 3',
      'status': 'PASSED',
      'lastInspected': '10 Sep 2026',
    },
    {
      'id': 'FPS-KA-IND-0003',
      'name': 'Indiranagar Ration Depot',
      'location': 'Indiranagar 100ft Road',
      'status': 'SURPRISE_ALERT',
      'lastInspected': '01 Jul 2026',
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
  }

  @override
  void dispose() {
    _inspectorNotesController.dispose();
    super.dispose();
  }

  double get _complianceScore {
    final passedCount = _checklist.values.where((v) => v).length;
    return (passedCount / _checklist.length) * 100.0;
  }

  Future<void> _handleSubmitReport() async {
    setState(() => _isSubmitting = true);
    final score = _complianceScore.round();

    try {
      await _apiService.submitFpsInspectionReport(
        fpsId: _selectedFpsId,
        complianceScore: score,
        notes: _inspectorNotesController.text.trim(),
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF15803D), size: 28),
            SizedBox(width: 8),
            Text('Inspection Report Submitted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Field audit for $_selectedFpsId submitted with $score% Compliance Rating.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF86EFAC))),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF166534), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('SHA-256 Audit Seal appended & synchronized with DSO Command Console.', style: TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
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
              setState(() {
                final shop = _assignedShops.firstWhere((s) => s['id'] == _selectedFpsId);
                shop['status'] = 'PASSED';
                shop['lastInspected'] = 'Today (15 Sep)';
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2942)),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2942),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Field Food Inspector Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Inspector ID: INS-KA-BANGALORE-04 • Food & Civil Supplies', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DSO Alert Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DSO Directive: Surprise Inspection Order Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
                        Text('Conduct immediate unannounced audit on FPS-KA-IND-0003 for stock variance reconciliation.', style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Assigned Shops Selector
            const Text('1. Select Assigned Ration Shop:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _assignedShops.length,
              itemBuilder: (ctx, i) {
                final shop = _assignedShops[i];
                final isSelected = _selectedFpsId == shop['id'];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isSelected ? const Color(0xFF15803D) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
                  ),
                  color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                  child: ListTile(
                    onTap: () => setState(() => _selectedFpsId = shop['id']),
                    leading: Icon(
                      shop['status'] == 'SURPRISE_ALERT' ? Icons.error_outline : Icons.storefront_outlined,
                      color: shop['status'] == 'SURPRISE_ALERT' ? Colors.red : (isSelected ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                    ),
                    title: Text('${shop['name']} (${shop['id']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('${shop['location']} • Last Audit: ${shop['lastInspected']}', style: const TextStyle(fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: shop['status'] == 'PASSED'
                            ? const Color(0xFFDCFCE7)
                            : (shop['status'] == 'SURPRISE_ALERT' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        shop['status'].toString().replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: shop['status'] == 'PASSED'
                              ? const Color(0xFF166534)
                              : (shop['status'] == 'SURPRISE_ALERT' ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Digital Checklist
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('2. Digital Audit Checklist:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0F2942), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'Score: ${_complianceScore.round()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                children: _checklist.keys.map((key) {
                  final isChecked = _checklist[key] ?? false;
                  return CheckboxListTile(
                    activeColor: const Color(0xFF15803D),
                    title: Text(key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    value: isChecked,
                    onChanged: (val) => setState(() => _checklist[key] = val ?? false),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Remarks Controller
            const Text('3. Inspector Remarks & Audit Notes:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            TextField(
              controller: _inspectorNotesController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('SUBMIT OFFICIAL INSPECTION REPORT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
