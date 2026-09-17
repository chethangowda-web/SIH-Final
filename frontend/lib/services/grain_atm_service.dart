import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/grain_atm_model.dart';

class GrainAtmService {
  GrainAtmService._();
  static final GrainAtmService instance = GrainAtmService._();

  final http.Client _client = http.Client();

  /// Fetch machine status, commodity availability, and thresholds
  Future<GrainAtmStatus> getAtmStatus({String atmId = 'ATM-001'}) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/grain-atm/$atmId');
    try {
      final response = await _client.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GrainAtmStatus.fromJson(data);
      }
    } catch (e) {
      // Graceful fallback for offline demo
    }

    // Default simulation fallback
    return GrainAtmStatus(
      atmId: atmId,
      name: 'Ration Vending Machine — Demo PDS Centre',
      location: 'Demo PDS Centre, Malleshwaram, Bengaluru Urban',
      district: 'Bengaluru Urban',
      status: 'ONLINE',
      isReady: true,
      isLowStock: false,
      inventory: [
        GrainAtmStockItem(commodity: 'RICE', capacityKg: 500, availableStockKg: 182, minThresholdKg: 50, isLowStock: false),
        GrainAtmStockItem(commodity: 'WHEAT', capacityKg: 300, availableStockKg: 74, minThresholdKg: 30, isLowStock: false),
      ],
      lastReplenishedAt: '2026-09-15 10:30:00',
    );
  }

  /// Verify beneficiary identity and authoritative cycle receipt status
  Future<BeneficiaryAtmVerification> verifyBeneficiary({
    required String beneficiaryId,
    String cycleId = '2026-09',
    String authMethod = 'DEMO_BIOMETRIC',
    String? pinOrOtp,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/grain-atm/verify');
    final body = json.encode({
      'beneficiary_id': beneficiaryId.trim(),
      'cycle_id': cycleId,
      'auth_method': authMethod,
      'pin_or_otp': pinOrOtp,
    });

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BeneficiaryAtmVerification.fromJson(data);
      }
    } catch (e) {
      // Fallback
    }

    return BeneficiaryAtmVerification(
      beneficiaryId: beneficiaryId,
      name: 'Deepa Reddy',
      cardType: 'PHH',
      cycleId: cycleId,
      statutoryRiceKg: 20.0,
      statutoryWheatKg: 5.0,
      authorizedRiceKg: 10.0,
      authorizedWheatKg: 0.0,
      alreadyReceived: false,
      stockSufficient: true,
      eligible: true,
      atmId: 'ATM-001',
    );
  }

  /// Execute simulated dispensing transaction with atomic backend persistence
  Future<GrainAtmDispenseResult> dispenseRation({
    required String atmId,
    required String beneficiaryId,
    String cycleId = '2026-09',
    String authMethod = 'DEMO_BIOMETRIC',
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/grain-atm/dispense');
    final body = json.encode({
      'atm_id': atmId,
      'beneficiary_id': beneficiaryId.trim(),
      'cycle_id': cycleId,
      'auth_method': authMethod,
    });

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GrainAtmDispenseResult.fromJson(data);
      } else if (response.statusCode == 400) {
        final err = json.decode(response.body);
        return GrainAtmDispenseResult(
          success: false,
          transactionId: '',
          beneficiaryId: beneficiaryId,
          cycleId: cycleId,
          dispensedRiceKg: 0,
          dispensedWheatKg: 0,
          atmId: atmId,
          atmLocation: 'Demo PDS Centre',
          receiptHash: '',
          receiptQrData: '',
          timestamp: DateTime.now().toIso8601String(),
          errorMessage: err['detail'] ?? 'Your ration for this cycle has already been received.',
        );
      }
    } catch (e) {
      // Exception handling
    }

    return GrainAtmDispenseResult(
      success: false,
      transactionId: '',
      beneficiaryId: beneficiaryId,
      cycleId: cycleId,
      dispensedRiceKg: 0,
      dispensedWheatKg: 0,
      atmId: atmId,
      atmLocation: 'Demo PDS Centre',
      receiptHash: '',
      receiptQrData: '',
      timestamp: DateTime.now().toIso8601String(),
      errorMessage: 'Network error communicating with Ration Vending Machine.',
    );
  }

  /// Operational telemetry for Department Officials
  Future<GrainAtmNetworkSummary> getAtmNetworkSummary() async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/grain-atm/network-summary');
    try {
      final response = await _client.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GrainAtmNetworkSummary.fromJson(data);
      }
    } catch (_) {}

    return GrainAtmNetworkSummary(
      totalAtms: 5,
      onlineAtms: 4,
      lowStockAtms: 1,
      todayDispensedRiceKg: 842.0,
      todayDispensedWheatKg: 316.0,
      atms: [
        AtmOperationalDetail(
          atmId: 'ATM-001',
          name: 'Ration Vending Machine — Demo PDS Centre',
          location: 'Demo PDS Centre, Malleshwaram',
          status: 'ONLINE',
          riceStockKg: 182.0,
          wheatStockKg: 74.0,
          todayTransactions: 34,
          successfulTransactions: 32,
          failedTransactions: 2,
          lastReplenishment: '10:30 AM',
        ),
      ],
    );
  }
}
