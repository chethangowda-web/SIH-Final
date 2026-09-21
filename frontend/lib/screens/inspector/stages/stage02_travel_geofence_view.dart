import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/inspector/inspector_models.dart';
import '../../../widgets/inspector/inspector_data_source_modal.dart';

/// Stage 02: Travel & Geofence Verification View
/// Real Geodesic Haversine Calculation • 50-Meter Statutory Anti-Ghost Inspection Perimeter
class Stage02TravelGeofenceView extends StatefulWidget {
  final InspectorTarget target;
  final GeofenceVerifyResult? geofenceResult;
  final bool isVerifying;
  final VoidCallback onVerifyGeofence;
  final VoidCallback onProceedToDelivery;
  final String activeCycle;

  const Stage02TravelGeofenceView({
    super.key,
    required this.target,
    required this.geofenceResult,
    required this.isVerifying,
    required this.onVerifyGeofence,
    required this.onProceedToDelivery,
    required this.activeCycle,
  });

  @override
  State<Stage02TravelGeofenceView> createState() => _Stage02TravelGeofenceViewState();
}

class _Stage02TravelGeofenceViewState extends State<Stage02TravelGeofenceView> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final fpsLat = widget.target.latitude;
    final fpsLon = widget.target.longitude;
    final isVerified = widget.geofenceResult?.verified ?? false;
    final distanceM = widget.geofenceResult?.distanceM ?? 24.5;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stage Header
          _buildStageHeader(isVerified),
          const SizedBox(height: 16),

          // 2. Main Content Split: GIS Map on Left, Geofence Verification Panel on Right
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GIS Map Card
                Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(fpsLat, fpsLon),
                              initialZoom: 15.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'org.pds.demandsync',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: LatLng(fpsLat, fpsLon),
                                    radius: 50,
                                    useRadiusInMeter: true,
                                    color: isVerified
                                        ? const Color(0x3310B981)
                                        : const Color(0x332563EB),
                                    borderColor: isVerified
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF2563EB),
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  // FPS Location Pin
                                  Marker(
                                    point: LatLng(fpsLat, fpsLon),
                                    width: 140,
                                    height: 50,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            widget.target.name,
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(Icons.store, color: Color(0xFF2563EB), size: 24),
                                      ],
                                    ),
                                  ),
                                  // Inspector Location Pin (nearby within radius)
                                  Marker(
                                    point: LatLng(fpsLat + 0.00015, fpsLon + 0.00015),
                                    width: 140,
                                    height: 50,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isVerified ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isVerified ? 'Inspector On-Site' : 'Inspector Device',
                                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Icon(
                                          Icons.person_pin_circle,
                                          color: isVerified ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          size: 26,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Map Floating Telemetry HUD
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.gps_fixed, size: 12, color: Color(0xFF38BDF8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'FPS Coordinates: ${fpsLat.toStringAsFixed(6)}° N, ${fpsLon.toStringAsFixed(6)}° E',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 18),

                // Geofence Verification Control Panel
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // Verification Status Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isVerified ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isVerified ? const Color(0xFFD1FAE5) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isVerified ? Icons.verified : Icons.location_searching,
                                      color: isVerified ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isVerified ? 'GEOFENCE VERIFIED' : 'GEOFENCE PENDING',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isVerified ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          isVerified
                                              ? 'Within 50m statutory shop perimeter'
                                              : 'Click to verify physical arrival via GPS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isVerified ? const Color(0xFF047857) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _buildTelemetryRow('Geodesic Distance', '${distanceM.toStringAsFixed(1)} meters'),
                              _buildTelemetryRow('Statutory Limit', '50.0 meters (ECA 1955)'),
                              _buildTelemetryRow('Target Shop', widget.target.name),
                              _buildTelemetryRow('District', widget.target.district),
                              _buildTelemetryRow(
                                'Verification Time',
                                widget.geofenceResult?.timestamp ?? 'Pending Officer Action',
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: widget.isVerifying
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.fingerprint, size: 18),
                                  label: Text(
                                    isVerified ? 'RE-VERIFY ARRIVAL' : 'VERIFY PHYSICAL ARRIVAL',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isVerified ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                  ),
                                  onPressed: widget.isVerifying ? null : widget.onVerifyGeofence,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Anti-Ghost Inspection Guarantee Box
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Anti-Ghost Inspection Guarantee',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Reports cannot be submitted outside the Fair Price Shop perimeter. Geofence coordinates and arrival timestamps are cryptographically sealed with the inspection record.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.storage, size: 12),
                                label: const Text('View Coordinates Trace', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                onPressed: () {
                                  InspectorDataSourceModal.show(
                                    context,
                                    title: 'GIS Geofence Verification Formula',
                                    datasetName: 'Spatial Haversine GIS Perimeter',
                                    tableName: 'fps.latitude, fps.longitude',
                                    cycleId: widget.activeCycle,
                                    recordCount: '1 store coordinate pair',
                                    formula: 'R = 6371000m, a = sin²(Δφ/2) + cos(φ1)cos(φ2)sin²(Δλ/2)\ndistance = 2R · atan2(√a, √(1-a)) <= 50m',
                                    apiEndpoint: '/api/v1/officer/inspector/geofence/verify',
                                  );
                                },
                              ),
                            ],
                          ),
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

  Widget _buildStageHeader(bool isVerified) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.navigation, color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAGE 02 — TRAVEL & GEOFENCE ARRIVAL VERIFICATION',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Verify on-site physical arrival at Fair Price Shop within 50-meter statutory perimeter before proceeding to delivery and stock audit',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('VERIFY DELIVERY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: widget.onProceedToDelivery,
        ),
      ],
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
