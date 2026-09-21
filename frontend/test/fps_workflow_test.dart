import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/models/fps/fps_models.dart';

void main() {
  group('Fair Price Shop (FPS) Models & Workflow Parsing Tests', () {
    test('FpsOwnerProfile parses real database response correctly', () {
      final json = {
        'status': 'success',
        'fps_id': 'FPS-KA-BLR-002',
        'name': 'Fair Price Shop (FPS-KA-BLR-002)',
        'district': 'Bengaluru Urban',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'capacity_kg': 5000.0,
        'beneficiaries_count': 100,
        'active_cycle': '2026-09',
        'operating_status': 'OPEN',
        'dealer_name': 'Authorized Dealer (fps_user)',
        'dealer_phone': '+91-98450-88123',
        'assigned_depot': 'Bengaluru Central FCI Godown (Hebbal)',
        'operating_hours': '08:00 AM - 08:00 PM',
        'authenticated_user': 'fps_user',
        'role': 'FPS_OWNER',
      };

      final profile = FpsOwnerProfile.fromJson(json);
      expect(profile.fpsId, 'FPS-KA-BLR-002');
      expect(profile.name, 'Fair Price Shop (FPS-KA-BLR-002)');
      expect(profile.district, 'Bengaluru Urban');
      expect(profile.operatingStatus, 'OPEN');
      expect(profile.capacityKg, 5000.0);
      expect(profile.beneficiariesCount, 100);
      expect(profile.activeCycle, '2026-09');
    });

    test('FpsDashboardOverview parses KPI counts and attention items', () {
      final json = {
        'status': 'success',
        'fps_id': 'FPS-KA-BLR-002',
        'cycle_id': '2026-09',
        'shop_status': 'OPEN',
        'kpis': {
          'total_beneficiaries': 100,
          'served_beneficiaries': 25,
          'pending_beneficiaries': 75,
          'current_rice_stock_kg': 1450.0,
          'current_wheat_stock_kg': 380.0,
          'current_sugar_stock_kg': 120.0,
          'current_kerosene_l': 90.0,
          'today_distributed_rice_kg': 70.0,
          'today_distributed_wheat_kg': 20.0,
          'today_transactions_count': 5,
          'cycle_distributed_rice_kg': 350.0,
          'cycle_distributed_wheat_kg': 100.0,
          'cycle_transactions_count': 25,
          'pending_deliveries_count': 1,
          'stock_days_remaining': 15.5,
          'open_exceptions_count': 0,
        },
        'attention_items': [
          {
            'id': 'ATTN-DELIV-01',
            'type': 'DELIVERY',
            'severity': 'HIGH',
            'title': '1 Inbound Consignment Awaiting Receipt',
            'description': 'Truck manifest dispatched from Central Godown.',
            'action': 'VERIFY_DELIVERY',
          }
        ],
      };

      final overview = FpsDashboardOverview.fromJson(json);
      expect(overview.fpsId, 'FPS-KA-BLR-002');
      expect(overview.kpis.totalBeneficiaries, 100);
      expect(overview.kpis.servedBeneficiaries, 25);
      expect(overview.kpis.currentRiceStockKg, 1450.0);
      expect(overview.kpis.stockDaysRemaining, 15.5);
      expect(overview.attentionItems.length, 1);
      expect(overview.attentionItems.first.action, 'VERIFY_DELIVERY');
    });

    test('FpsBeneficiaryRecord parses NFSA statutory entitlement calculations', () {
      final json = {
        'beneficiary_id': 'BEN-KA-0001',
        'name': 'Deepa Reddy',
        'phone': '+91-9845012345',
        'scheme_type': 'PHH',
        'members_count': 2,
        'statutory_rice_kg': 7.0,
        'statutory_wheat_kg': 3.0,
        'statutory_total_kg': 10.0,
        'is_collected': false,
        'collected_at': null,
        'received_rice_kg': 0.0,
        'received_wheat_kg': 0.0,
        'remaining_rice_kg': 7.0,
        'remaining_wheat_kg': 3.0,
      };

      final ben = FpsBeneficiaryRecord.fromJson(json);
      expect(ben.beneficiaryId, 'BEN-KA-0001');
      expect(ben.schemeType, 'PHH');
      expect(ben.membersCount, 2);
      expect(ben.statutoryRiceKg, 7.0);
      expect(ben.remainingRiceKg, 7.0);
      expect(ben.isCollected, false);
    });

    test('FpsInboundDelivery parses truck, manifest and telemetry metadata', () {
      final json = {
        'gatepass_id': 'GP-2026-0914',
        'truck_id': 'KA-04-E-1024',
        'manifest_id': 'MNF-2026-09-001',
        'driver_name': 'Ramesh Kumar',
        'driver_phone': '+91-98450-12345',
        'source_depot': 'Bengaluru Central FCI Godown (Hebbal)',
        'destination_fps_id': 'FPS-KA-BLR-002',
        'dispatched_rice_kg': 2450.0,
        'dispatched_wheat_kg': 450.0,
        'total_payload_kg': 2900.0,
        'status': 'IN_TRANSIT',
        'issued_at': '2026-09-21 08:30:00',
        'verified_at': null,
        'current_lat': 12.9716,
        'current_lon': 77.5946,
        'live_tracking_available': true,
      };

      final del = FpsInboundDelivery.fromJson(json);
      expect(del.gatepassId, 'GP-2026-0914');
      expect(del.truckId, 'KA-04-E-1024');
      expect(del.status, 'IN_TRANSIT');
      expect(del.dispatchedRiceKg, 2450.0);
      expect(del.liveTrackingAvailable, true);
    });

    test('FpsEposDispenseResult parses atomic dispensation confirmation', () {
      final json = {
        'transaction_id': 'TX-EPOS-9A8B7C6D',
        'beneficiary_id': 'BEN-KA-0001',
        'fps_id': 'FPS-KA-BLR-002',
        'cycle_id': '2026-09',
        'rice_dispensed_kg': 7.0,
        'wheat_dispensed_kg': 3.0,
        'remaining_fps_rice_stock_kg': 1443.0,
        'remaining_fps_wheat_stock_kg': 377.0,
        'status': 'SUCCESS_DISPENSED',
        'receipt_confirmed_at': '2026-09-21 11:30:00',
      };

      final res = FpsEposDispenseResult.fromJson(json);
      expect(res.transactionId, 'TX-EPOS-9A8B7C6D');
      expect(res.riceDispensedKg, 7.0);
      expect(res.remainingFpsRiceStockKg, 1443.0);
      expect(res.status, 'SUCCESS_DISPENSED');
    });
  });
}
