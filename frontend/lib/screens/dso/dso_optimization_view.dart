import 'package:flutter/material.dart';
import '../../services/dso/dso_service.dart';

class DsoOptimizationView extends StatefulWidget {
  final DsoService dsoService;
  final String cycleId;
  final VoidCallback onOptimizationApproved;

  const DsoOptimizationView({
    super.key,
    required this.dsoService,
    required this.cycleId,
    required this.onOptimizationApproved,
  });

  @override
  State<DsoOptimizationView> createState() => _DsoOptimizationViewState();
}

class _DsoOptimizationViewState extends State<DsoOptimizationView> {
  bool _loading = true;
  bool _approving = false;
  Map<String, dynamic>? _routesData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.dsoService.getSupplyRoutes(cycleId: widget.cycleId);
      setState(() {
        _routesData = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleApproveOptimization() async {
    setState(() => _approving = true);
    try {
      await widget.dsoService.approveOptimization(cycleId: widget.cycleId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route Optimization Approved! State advanced to OPTIMIZED.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      widget.onOptimizationApproved();
      await _loadRoutes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve optimization: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      setState(() => _approving = false);
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
            ElevatedButton(onPressed: _loadRoutes, child: const Text('Retry')),
          ],
        ),
      );
    }

    final routes = (_routesData?['routes'] as List<dynamic>? ?? []);

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
                    Text('Stage 04: Supply & Route Optimization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('VRP Fleet Routing • Depot -> Vehicle -> Corridor Stops -> FPS Delivery Sequence', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: _approving ? null : _handleApproveOptimization,
                child: _approving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        children: const [
                          Icon(Icons.alt_route, size: 18),
                          SizedBox(width: 8),
                          Text('APPROVE OPTIMIZATION PLAN', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Route Cards Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: routes.map((r) => _buildRouteCard(r as Map<String, dynamic>)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final stops = (route['stops'] as List<dynamic>? ?? []);

    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.local_shipping, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route['truck_id'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(route['corridor'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)),
                child: Text(route['route_status'] ?? 'READY', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Driver: ${route['driver_name'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              Text('Payload: ${route['total_quantity_kg']} / ${route['payload_capacity_kg']} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),

          const Text('Delivery Stops Sequence:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          ...stops.map((s) {
            final st = s as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(radius: 10, backgroundColor: const Color(0xFF2563EB), child: Text('${st['sequence']}', style: const TextStyle(color: Colors.white, fontSize: 10))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${st['fps_name']} (${st['commodity']})', style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)))),
                  Text('${st['quantity_kg']} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
