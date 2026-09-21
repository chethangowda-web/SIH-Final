import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pds_demandsync/screens/dso/dso_command_center_screen.dart';
import 'package:pds_demandsync/services/dso/dso_service.dart';
import 'package:pds_demandsync/models/dso/dso_models.dart';

// Fake backend: returns real-shaped /admin/dso/* payloads without network.
class _StubClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 500);
  }
}

class FakeDsoService extends DsoService {
  FakeDsoService() : super(client: _StubClient());

  @override
  Future<Map<String, dynamic>> getActiveCycleStatus({String? cycleId}) async {
    return {'cycle_id': '2026-09', 'status': 'CHOICE_WINDOW_OPEN'};
  }

  @override
  Future<List<String>> getDistricts() async {
    return ['Bengaluru Urban'];
  }

  @override
  Future<DsoCommandOverview> getCommandOverview(
      {String cycleId = '2026-09', String district = 'Ramanagara'}) async {
    return DsoCommandOverview.fromJson({
      'status': 'success',
      'district': 'Bengaluru Urban',
      'cycle_id': '2026-09',
      // Real backend value from workflow_manager.WorkflowState.
      'current_stage': 'FORECASTED',
      'metrics': {
        'beneficiaries': {'count': 10000},
        'active_intents': {'count': 420},
        'intent_demand': {'count': 276700.0},
        'forecast_demand': {'count': 260000.0},
        'baseline_demand': {'count': 255000.0},
        'fps': {'count': 621},
        'depot_stock_kg': {'count': 5000000.0},
        'fps_inventory_kg': {'count': 24500.0},
      },
      'demand_breakdown': <String, dynamic>{},
      'exceptions': [],
      'ai_insights': [],
      'ai_recommendation': <String, dynamic>{},
      'data_last_updated': '10:00 AM',
    });
  }

  @override
  Future<List<GovernanceEventItem>> getGovernanceEvents(
      {String cycleId = '2026-09', int limit = 20}) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> getDemandValidation(
      {String cycleId = '2026-09'}) async {
    return {};
  }

  @override
  Future<DsoAllocationPlan> getAllocationPlan(
      {String cycleId = '2026-09'}) async {
    return DsoAllocationPlan(
      cycleId: cycleId,
      availableDepotStockMt: 0,
      totalValidatedDemandMt: 0,
      totalExistingFpsStockMt: 0,
      totalNetRequirementMt: 0,
      totalProposedAllocationMt: 0,
      totalShortfallMt: 0,
      unallocatedDepotBalanceMt: 0,
      items: [],
    );
  }

  @override
  Future<Map<String, dynamic>> getSupplyRoutes(
      {String cycleId = '2026-09'}) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> getDispatchManifests(
      {String cycleId = '2026-09'}) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> getDeliveryVerification(
      {String cycleId = '2026-09'}) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> getCycleEvaluation(
      {String cycleId = '2026-09'}) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> getReconciliation(
      {String cycleId = '2026-09'}) async {
    return {};
  }
}

void main() {
  testWidgets(
      'DSO Command Center renders workflow cycle with seven stages, no dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DsoCommandCenterScreen(
          dsoService: FakeDsoService(),
          username: 'dso_user',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Workflow-first identity.
    expect(find.text('PDS DemandSync'), findsOneWidget);
    expect(find.text('DSO Command Center'), findsOneWidget);
    expect(find.text('DSO COMMAND CENTER'), findsOneWidget);
    expect(find.textContaining('STAGE 1 OF 7'), findsWidgets);
    expect(find.textContaining('MONITOR & TRIAGE'), findsWidgets);

    // Circular cycle hub + all seven stage nodes, no sidebar/dashboard grids.
    expect(find.text('MONITOR'), findsWidgets);
    expect(find.text('VALIDATE'), findsWidgets);
    expect(find.text('ALLOCATE'), findsWidgets);
    expect(find.text('OPTIMIZE'), findsWidgets);
    expect(find.text('AUTHORIZE'), findsWidgets);
    expect(find.text('VERIFY'), findsWidgets);
    expect(find.text('EVALUATE'), findsWidgets);

    // Stage workspace with operational actions + traceability entries.
    expect(find.textContaining('STAGE 01 OF 7'), findsWidgets);
    expect(find.text('View Data Source'), findsWidgets);
    expect(find.text('View Decision Trace'), findsWidgets);

    // Real backend-shaped numbers render as operational facts.
    expect(find.textContaining('276.7 MT'), findsWidgets);
    expect(find.textContaining('260.0 MT'), findsWidgets);
  });
}
