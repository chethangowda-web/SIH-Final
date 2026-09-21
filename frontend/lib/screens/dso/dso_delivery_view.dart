import 'package:flutter/material.dart';
import '../../services/dso/dso_service.dart';

class DsoDeliveryView extends StatefulWidget {
  final DsoService dsoService;
  final String cycleId;

  const DsoDeliveryView({
    super.key,
    required this.dsoService,
    required this.cycleId,
  });

  @override
  State<DsoDeliveryView> createState() => _DsoDeliveryViewState();
}

class _DsoDeliveryViewState extends State<DsoDeliveryView> {
  bool _loading = true;
  Map<String, dynamic>? _deliveryData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeliveryData();
  }

  Future<void> _loadDeliveryData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.dsoService.getDeliveryVerification(cycleId: widget.cycleId);
      setState(() {
        _deliveryData = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showSurpriseInspectionDialog() {
    final fpsController = TextEditingController(text: 'FPS-KA-017');
    final reasonController = TextEditingController(text: 'Demand anomaly spike detected during choice window.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue Surprise Inspection Directive'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fpsController,
              decoration: const InputDecoration(labelText: 'Target Fair Price Shop ID', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Statutory Inspection Reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              final fps = fpsController.text.trim();
              final reason = reasonController.text.trim();
              if (fps.isEmpty || reason.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                final res = await widget.dsoService.surpriseInspection(fpsId: fps, reason: reason);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Surprise Inspection Directive Issued! ID: ${res['order_id']}'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
                await _loadDeliveryData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error issuing directive: $e'), backgroundColor: const Color(0xFFDC2626)),
                );
              }
            },
            child: const Text('ISSUE DIRECTIVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Color(0xFFDC2626))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadDeliveryData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final shipments = (_deliveryData?['active_shipments'] as List<dynamic>? ?? []);
    final inspections = (_deliveryData?['inspections'] as List<dynamic>? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Stage 06: Verify Delivery & Inspection Integration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Real-time Transit Telemetry & Field Food Inspector Synchronization', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _showSurpriseInspectionDialog,
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('ISSUE SURPRISE INSPECTION', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Active Telemetry Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Transit Telemetry Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      columns: const [
                        DataColumn(label: Text('Truck ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Target FPS', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Distance to Target', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ETA / Updated', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: shipments.map((s) {
                        final item = s as Map<String, dynamic>;
                        return DataRow(
                          cells: [
                            DataCell(Text(item['truck_id'] ?? 'TRK-01', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(item['fps_id'] ?? 'FPS-KA-001')),
                            DataCell(Text('${item['distance_km'] ?? 12.4} km')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)),
                                child: Text(item['status'] ?? 'IN_TRANSIT', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                              ),
                            ),
                            DataCell(Text(item['eta'] ?? item['updated_at'] ?? '24 mins')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Field Inspector Reports
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Field Food Inspector Sealed Records', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),

                  inspections.isEmpty
                      ? const Text('No inspection records available.', style: TextStyle(color: Color(0xFF64748B)))
                      : Column(
                          children: inspections.map((i) {
                            final insp = i as Map<String, dynamic>;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified, color: Color(0xFF16A34A), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Inspection: ${insp['inspection_id']} — ${insp['fps_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('Remarks: ${insp['remarks'] ?? "Compliant"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Text('Score: ${insp['compliance_score'] ?? 100}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
