import 'package:flutter/material.dart';
import '../../services/dso/dso_service.dart';

class DsoDispatchView extends StatefulWidget {
  final DsoService dsoService;
  final String cycleId;
  final VoidCallback onDispatchAuthorized;

  const DsoDispatchView({
    super.key,
    required this.dsoService,
    required this.cycleId,
    required this.onDispatchAuthorized,
  });

  @override
  State<DsoDispatchView> createState() => _DsoDispatchViewState();
}

class _DsoDispatchViewState extends State<DsoDispatchView> {
  bool _loading = true;
  bool _authorizing = false;
  List<dynamic> _manifests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadManifests();
  }

  Future<void> _loadManifests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.dsoService.getDispatchManifests(cycleId: widget.cycleId);
      setState(() {
        _manifests = (res['manifests'] as List<dynamic>? ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleAuthorize(String manifestId) async {
    setState(() => _authorizing = true);
    try {
      final res = await widget.dsoService.authorizeDispatch(
        manifestId: manifestId,
        cycleId: widget.cycleId,
        officerName: 'Dr. S. Kumar',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispatch Authorized! Reference: ${res['authorization_reference']}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      widget.onDispatchAuthorized();
      await _loadManifests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authorization error: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      setState(() => _authorizing = false);
    }
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
            ElevatedButton(onPressed: _loadManifests, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stage 05: Authorize Dispatch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('7-Point Pre-Authorization Statutory Readiness Verification Engine', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dispatch Manifests & Gatepass Readiness', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      columns: const [
                        DataColumn(label: Text('Manifest ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Truck ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Corridor', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Quantity (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Gatepass ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _manifests.map((m) {
                        final mItem = m as Map<String, dynamic>;
                        final mid = mItem['manifest_id'] ?? '';
                        final isDispatched = mItem['status'] == 'DISPATCHED' || mItem['status'] == 'DELIVERED';

                        return DataRow(
                          cells: [
                            DataCell(Text(mid, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(mItem['truck_id'] ?? 'TRK-KA-0031')),
                            DataCell(Text(mItem['corridor'] ?? 'East Corridor')),
                            DataCell(Text('${mItem['total_quantity_kg']}')),
                            DataCell(Text(mItem['gatepass_id'] ?? 'GP-MAN-01', style: const TextStyle(fontFamily: 'monospace'))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDispatched ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mItem['status'] ?? 'GATEPASS_READY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDispatched ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              isDispatched
                                  ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20)
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      onPressed: _authorizing ? null : () => _handleAuthorize(mid),
                                      child: const Text('AUTHORIZE DISPATCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
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
