import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/models/inspector/inspector_models.dart';

void main() {
  group('Field Food Inspector Models & Workflow Parsing Tests', () {
    test('InspectorTarget parses real database response correctly', () {
      final json = {
        'fps_id': 'FPS-KA-BNG-001',
        'name': 'Vijayanagar Fair Price Depot #1',
        'district': 'Bengaluru Urban',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'beneficiaries_count': 420,
        'capacity_kg': 6500.0,
        'reason': 'High demand variance vs historical baseline',
        'priority': 'HIGH',
        'rice_stock_kg': 2400.0,
        'wheat_stock_kg': 1200.0,
        'previous_inspections_count': 3,
        'last_compliance_score': 92.5,
      };

      final target = InspectorTarget.fromJson(json);
      expect(target.fpsId, 'FPS-KA-BNG-001');
      expect(target.name, 'Vijayanagar Fair Price Depot #1');
      expect(target.priority, 'HIGH');
      expect(target.latitude, 12.9716);
      expect(target.longitude, 77.5946);
      expect(target.riceStockKg, 2400.0);
      expect(target.wheatStockKg, 1200.0);
      expect(target.lastComplianceScore, 92.5);
    });

    test('InboundDispatchInfo parses dispatch manifest and telemetry correctly', () {
      final json = {
        'manifest_id': 'MNF-202609-001',
        'truck_id': 'KA-01-EA-1001',
        'driver_name': 'Ramesh Kumar',
        'driver_phone': '9876543210',
        'origin_depot_name': 'Bengaluru Central Godown #4',
        'current_status': 'IN_TRANSIT',
        'allocated_quantity_kg': 1500.0,
        'dispatched_quantity_kg': 1500.0,
        'current_lat': 12.9650,
        'current_lon': 77.5850,
        'telemetry_status': 'LIVE',
        'eta_minutes': 18,
      };

      final dispatch = InboundDispatchInfo.fromJson(json);
      expect(dispatch.manifestId, 'MNF-202609-001');
      expect(dispatch.currentStatus, 'IN_TRANSIT');
      expect(dispatch.dispatchedQuantityKg, 1500.0);
      expect(dispatch.currentLat, 12.9650);
      expect(dispatch.etaMinutes, 18);
    });

    test('GeofenceVerifyResult parses verification status and radius', () {
      final json = {
        'verified': true,
        'geofence_status': 'WITHIN_GEOFENCE',
        'distance_meters': 34.2,
        'statutory_radius_m': 50.0,
        'timestamp': '2026-09-21T10:02:15',
        'fps_name': 'FPS-KA-BNG-001',
        'verified_by': 'inspector_user',
        'message': 'Physical arrival verified within Fair Price Shop 50m perimeter.',
      };

      final res = GeofenceVerifyResult.fromJson(json);
      expect(res.verified, true);
      expect(res.distanceM, 34.2);
      expect(res.statutoryRadiusM, 50.0);
      expect(res.fpsName, 'FPS-KA-BNG-001');
    });

    test('SealedInspectionReport parses immutable cryptographic seal and metrics', () {
      final json = {
        'inspection_id': 'INSP-202609-0042',
        'fps_id': 'FPS-KA-BNG-001',
        'fps_name': 'Vijayanagar Fair Price Depot #1',
        'fps_district': 'Bengaluru Urban',
        'inspector_id': 'inspector_user',
        'compliance_score': 95.0,
        'status': 'SEALED',
        'sealed_hash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'sealed_at': '2026-09-21T11:45:05',
        'remarks': 'Physical stocks match manifest with minor moisture variance',
        'observed_rice_kg': 1488.0,
        'observed_wheat_kg': 800.0,
        'rice_diff_kg': -12.0,
        'wheat_diff_kg': 0.0,
        'seizure_issued': 0,
        'evidence': [
          {
            'evidence_id': 'EV-001',
            'evidence_type': 'PHOTOGRAPH',
            'description': 'Stack inspection photo',
            'reference_path': '/evidence/stack1.jpg',
            'created_at': '2026-09-21T11:20:00',
            'inspector_id': 'inspector_user',
          }
        ],
      };

      final report = SealedInspectionReport.fromJson(json);
      expect(report.inspectionId, 'INSP-202609-0042');
      expect(report.sealedHash, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(report.status, 'SEALED');
      expect(report.complianceScore, 95.0);
      expect(report.evidence.length, 1);
      expect(report.evidence.first.id, 'EV-001');
    });
  });
}
