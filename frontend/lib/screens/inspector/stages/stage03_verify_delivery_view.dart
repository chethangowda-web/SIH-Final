import 'package:flutter/material.dart';
import '../../../models/inspector/inspector_models.dart';
import '../../../widgets/inspector/inspector_data_source_modal.dart';

/// Stage 03: Verify FPS & Inbound Truck Delivery View
/// Real Fleet Master • Authoritative Manifest & Gatepass • Corridor Movement Clearance
class Stage03VerifyDeliveryView extends StatelessWidget {
  final InspectorTarget target;
  final InboundDispatchInfo? dispatchInfo;
  final bool isLoadingDispatch;
  final bool isApprovingMovement;
  final VoidCallback onApproveMovement;
  final VoidCallback onProceedToInspection;
  final String activeCycle;

  const Stage03VerifyDeliveryView({
    super.key,
    required this.target,
    required this.dispatchInfo,
    required this.isLoadingDispatch,
    required this.isApprovingMovement,
    required this.onApproveMovement,
    required this.onProceedToInspection,
    required this.activeCycle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stage Header
          _buildStageHeader(),
          const SizedBox(height: 16),

          // 2. Main Content
          Expanded(
            child: isLoadingDispatch
                ? const Center(child: CircularProgressIndicator())
                : (dispatchInfo == null
                    ? _buildEmptyDispatchCard(context)
                    : _buildDispatchContent(context, dispatchInfo!)),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.local_shipping, color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAGE 03 — VERIFY FPS & INBOUND TRUCK DELIVERY',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Verify inbound grain consignment against authorized manifest & gatepass. Issue statutory movement clearance for carrier fleet.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('6-POINT INSPECTION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onProceedToInspection,
        ),
      ],
    );
  }

  Widget _buildEmptyDispatchCard(BuildContext context) {
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text(
                'No Active Inbound Truck Dispatch for this Shop',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Shop is operating on existing warehouse inventory. You may proceed directly to the physical 6-point inspection.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.fact_check, size: 16),
                label: const Text('PROCEED TO 6-POINT INSPECTION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: onProceedToInspection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchContent(BuildContext context, InboundDispatchInfo disp) {
    final isCleared = disp.movementApprovalStatus == 'APPROVED';
    return ListView(
      children: [
        // 1. Truck & Carrier Master Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: disp.currentStatus == 'IN_TRANSIT' ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'STATUS: ${disp.currentStatus}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: disp.currentStatus == 'IN_TRANSIT' ? const Color(0xFF2563EB) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Carrier: ${disp.truckId} (${disp.vehicleModel})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.storage, size: 14),
                      label: const Text('View Manifest Data Source', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        InspectorDataSourceModal.show(
                          context,
                          title: 'Manifest & Fleet: ${disp.manifestId}',
                          datasetName: 'Truck Fleet Master & Dispatch Manifests',
                          tableName: 'manifests JOIN vehicles JOIN gatepasses',
                          cycleId: activeCycle,
                          recordCount: 'Verified in SQLite',
                          formula: 'SELECT * FROM manifests WHERE manifest_id = "${disp.manifestId}"',
                          apiEndpoint: '/api/v1/officer/fps/${target.fpsId}/assigned-dispatch',
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    _buildInfoColumn('Manifest ID', disp.manifestId),
                    _buildInfoColumn('Gatepass Token', disp.gatepassId),
                    _buildInfoColumn('Driver Name', disp.driverName),
                    _buildInfoColumn('Driver Phone', disp.driverPhone),
                    _buildInfoColumn('Source Godown', disp.originDepotName),
                    _buildInfoColumn('Dispatched Quantity', '${disp.dispatchedQuantityKg.toStringAsFixed(0)} kg ${disp.commodity}'),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Telemetry & Movement Clearance Dual Section
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Telemetry & Progress
            Expanded(
              flex: 3,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sensors, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Text(
                            'Transit Telemetry & Route Progression',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildTelemetryTile('Speed', '${disp.speedKmh.toStringAsFixed(1)} km/h'),
                          _buildTelemetryTile('Travelled', '${disp.distanceTravelledKm.toStringAsFixed(1)} km'),
                          _buildTelemetryTile('Remaining', '${disp.distanceRemainingKm.toStringAsFixed(1)} km'),
                          _buildTelemetryTile('ETA', disp.expectedArrivalTime),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Corridor: ${disp.routeName}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last GPS Sync: ${disp.lastTelemetryTime}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Right: Officer Movement Clearance Action
            Expanded(
              flex: 2,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isCleared ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCleared ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCleared ? Icons.verified : Icons.lock_clock,
                            size: 18,
                            color: isCleared ? const Color(0xFF059669) : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCleared ? 'MOVEMENT CLEARED' : 'OFFICER CLEARANCE REQUIRED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCleared ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isCleared
                            ? 'Truck ${disp.truckId} is officially authorized to proceed to subsequent delivery stops.'
                            : 'Verify physical delivery of ${disp.dispatchedQuantityKg.toStringAsFixed(0)} kg ${disp.commodity} and grant onward transit authorization.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isCleared ? const Color(0xFF047857) : const Color(0xFF1E3A8A),
                          height: 1.3,
                        ),
                      ),
                      if (disp.movementClearanceToken != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Token: ${disp.movementClearanceToken}',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF065F46), fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isApprovingMovement
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(
                            isCleared ? 'CLEARANCE RECORDED' : 'APPROVE TRUCK MOVEMENT',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCleared ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                          ),
                          onPressed: (isCleared || isApprovingMovement) ? null : onApproveMovement,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Multi-Stop Route Corridor List
        if (disp.multiFpsStops.isNotEmpty) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Corridor Delivery Stops Sequence',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  ...disp.multiFpsStops.map((stop) {
                    final isTarget = stop['is_target'] == true || stop['fps_id'] == target.fpsId;
                    final isStopCleared = stop['is_cleared'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isTarget ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isTarget ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isTarget ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${stop['sequence'] ?? 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${stop['fps_name']} (${stop['fps_id']})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isTarget ? FontWeight.bold : FontWeight.w500,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Text(
                            '${stop['quantity_kg']} kg ${stop['commodity']}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isStopCleared ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isStopCleared ? 'CLEARED' : 'PENDING',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isStopCleared ? const Color(0xFF059669) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }
}
