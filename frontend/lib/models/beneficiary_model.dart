/// Data Models for Beneficiary Experience in PDS DemandSync.

class Beneficiary {
  final int id;
  final String pseudonymousBeneficiaryId;
  final String nameForDemo;
  final String registeredFpsId;
  final String? registeredFpsName;
  final String language;
  final String status;
  final List<Map<String, dynamic>> activeIntents;

  Beneficiary({
    required this.id,
    required this.pseudonymousBeneficiaryId,
    required this.nameForDemo,
    required this.registeredFpsId,
    this.registeredFpsName,
    required this.language,
    required this.status,
    this.activeIntents = const [],
  });

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json['id'] ?? 0,
      pseudonymousBeneficiaryId: json['pseudonymous_beneficiary_id'] ?? '',
      nameForDemo: json['name_for_demo'] ?? '',
      registeredFpsId: json['registered_fps_id'] ?? '',
      registeredFpsName: json['registered_fps_name'],
      language: json['language'] ?? 'kn',
      status: json['status'] ?? 'ACTIVE',
      activeIntents: (json['active_intents'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }
}

class FpsShop {
  final int id;
  final String fpsId;
  final String name;
  final String district;
  final double latitude;
  final double longitude;
  final double capacityKg;
  final String status;
  final double currentInventoryTotalKg;
  final double declaredIntentCycleKg;

  FpsShop({
    required this.id,
    required this.fpsId,
    required this.name,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.capacityKg,
    required this.status,
    this.currentInventoryTotalKg = 0.0,
    this.declaredIntentCycleKg = 0.0,
  });

  factory FpsShop.fromJson(Map<String, dynamic> json) {
    return FpsShop(
      id: json['id'] ?? 0,
      fpsId: json['fps_id'] ?? '',
      name: json['name'] ?? '',
      district: json['district'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'ACTIVE',
      currentInventoryTotalKg:
          (json['current_inventory_total_kg'] as num?)?.toDouble() ?? 0.0,
      declaredIntentCycleKg:
          (json['declared_intent_cycle_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class IntentRecord {
  final int id;
  final String beneficiaryId;
  final String cycleId;
  final String intendedFpsId;
  final String? intendedFpsName;
  final String? homeFpsId;
  final bool isPortabilityIntent;
  final String commodity;
  final double declaredQuantityKg;
  final double confidence;
  final String createdAt;
  final String status;

  IntentRecord({
    required this.id,
    required this.beneficiaryId,
    required this.cycleId,
    required this.intendedFpsId,
    this.intendedFpsName,
    this.homeFpsId,
    this.isPortabilityIntent = false,
    required this.commodity,
    required this.declaredQuantityKg,
    required this.confidence,
    required this.createdAt,
    required this.status,
  });

  factory IntentRecord.fromJson(Map<String, dynamic> json) {
    return IntentRecord(
      id: json['id'] ?? 0,
      beneficiaryId: json['beneficiary_id'] ?? '',
      cycleId: json['cycle_id'] ?? '',
      intendedFpsId: json['intended_fps_id'] ?? '',
      intendedFpsName: json['intended_fps_name'],
      homeFpsId: json['home_fps_id'],
      isPortabilityIntent: json['is_portability_intent'] ?? false,
      commodity: json['commodity'] ?? '',
      declaredQuantityKg:
          (json['declared_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      createdAt: json['created_at'] ?? '',
      status: json['status'] ?? 'SUBMITTED',
    );
  }
}
