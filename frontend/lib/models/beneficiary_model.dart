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
  final String deliveryMode;
  final String? deliveryAddress;
  final double deliveryDistanceKm;
  final double transportFeeInr;
  final String deliveryStatus;
  final double statutoryEntitlementKg;
  final double remainingBalanceKg;
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
    this.deliveryMode = 'FPS_COLLECTION',
    this.deliveryAddress,
    this.deliveryDistanceKm = 0.0,
    this.transportFeeInr = 0.0,
    this.deliveryStatus = 'SERVICE_REQUESTED',
    this.statutoryEntitlementKg = 20.0,
    this.remainingBalanceKg = 20.0,
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
      deliveryMode: json['delivery_mode'] ?? 'FPS_COLLECTION',
      deliveryAddress: json['delivery_address'],
      deliveryDistanceKm:
          (json['delivery_distance_km'] as num?)?.toDouble() ?? 0.0,
      transportFeeInr:
          (json['transport_fee_inr'] as num?)?.toDouble() ?? 0.0,
      deliveryStatus: json['delivery_status'] ?? 'SERVICE_REQUESTED',
      statutoryEntitlementKg:
          (json['statutory_entitlement_kg'] as num?)?.toDouble() ?? 20.0,
      remainingBalanceKg:
          (json['remaining_balance_kg'] as num?)?.toDouble() ?? 20.0,
      createdAt: json['created_at'] ?? '',
      status: json['status'] ?? 'SUBMITTED',
    );
  }
}

class TransportFeeBreakdown {
  final String deliveryMode;
  final double deliveryDistanceKm;
  final double baseTransportFeeInr;
  final double distanceSurchargeInr;
  final double totalTransportFeeInr;
  final double commodityCostInr;
  final double totalPayableInr;
  final String statutoryNotice;

  TransportFeeBreakdown({
    required this.deliveryMode,
    required this.deliveryDistanceKm,
    required this.baseTransportFeeInr,
    required this.distanceSurchargeInr,
    required this.totalTransportFeeInr,
    required this.commodityCostInr,
    required this.totalPayableInr,
    required this.statutoryNotice,
  });

  factory TransportFeeBreakdown.fromJson(Map<String, dynamic> json) {
    return TransportFeeBreakdown(
      deliveryMode: json['delivery_mode'] ?? 'FPS_COLLECTION',
      deliveryDistanceKm: (json['delivery_distance_km'] as num?)?.toDouble() ?? 0.0,
      baseTransportFeeInr: (json['base_transport_fee_inr'] as num?)?.toDouble() ?? 20.0,
      distanceSurchargeInr: (json['distance_surcharge_inr'] as num?)?.toDouble() ?? 0.0,
      totalTransportFeeInr: (json['total_transport_fee_inr'] as num?)?.toDouble() ?? 0.0,
      commodityCostInr: (json['commodity_cost_inr'] as num?)?.toDouble() ?? 0.0,
      totalPayableInr: (json['total_payable_inr'] as num?)?.toDouble() ?? 0.0,
      statutoryNotice: json['statutory_notice'] ??
          'Payment applies strictly to door-to-door transportation logistics and does not alter statutory entitlement.',
    );
  }
}

class BeneficiaryEntitlementSummary {
  final String beneficiaryId;
  final String name;
  final String cardType;
  final int familyMembersCount;
  final String cardLabel;
  final String cycleId;
  final String registeredFpsId;
  final String registeredFpsName;
  final double statutoryEntitlementRiceKg;
  final double statutoryEntitlementWheatKg;
  final double consumedRiceKg;
  final double consumedWheatKg;
  final double remainingEligibleRiceKg;
  final double remainingEligibleWheatKg;
  final double totalEligibleBalanceKg;
  final TransportFeeBreakdown transportPolicy;

  BeneficiaryEntitlementSummary({
    required this.beneficiaryId,
    required this.name,
    required this.cardType,
    required this.familyMembersCount,
    required this.cardLabel,
    required this.cycleId,
    required this.registeredFpsId,
    required this.registeredFpsName,
    required this.statutoryEntitlementRiceKg,
    required this.statutoryEntitlementWheatKg,
    required this.consumedRiceKg,
    required this.consumedWheatKg,
    required this.remainingEligibleRiceKg,
    required this.remainingEligibleWheatKg,
    required this.totalEligibleBalanceKg,
    required this.transportPolicy,
  });

  factory BeneficiaryEntitlementSummary.fromJson(Map<String, dynamic> json) {
    return BeneficiaryEntitlementSummary(
      beneficiaryId: json['beneficiary_id'] ?? '',
      name: json['name'] ?? '',
      cardType: json['card_type'] ?? 'PHH',
      familyMembersCount: json['family_members_count'] ?? 4,
      cardLabel: json['card_label'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      registeredFpsId: json['registered_fps_id'] ?? '',
      registeredFpsName: json['registered_fps_name'] ?? '',
      statutoryEntitlementRiceKg:
          (json['statutory_entitlement_rice_kg'] as num?)?.toDouble() ?? 20.0,
      statutoryEntitlementWheatKg:
          (json['statutory_entitlement_wheat_kg'] as num?)?.toDouble() ?? 5.0,
      consumedRiceKg:
          (json['consumed_rice_kg'] as num?)?.toDouble() ?? 0.0,
      consumedWheatKg:
          (json['consumed_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      remainingEligibleRiceKg:
          (json['remaining_eligible_rice_kg'] as num?)?.toDouble() ?? 20.0,
      remainingEligibleWheatKg:
          (json['remaining_eligible_wheat_kg'] as num?)?.toDouble() ?? 5.0,
      totalEligibleBalanceKg:
          (json['total_eligible_balance_kg'] as num?)?.toDouble() ?? 25.0,
      transportPolicy: json['transport_policy'] != null
          ? TransportFeeBreakdown.fromJson(json['transport_policy'])
          : TransportFeeBreakdown(
              deliveryMode: 'FPS_COLLECTION',
              deliveryDistanceKm: 0.0,
              baseTransportFeeInr: 20.0,
              distanceSurchargeInr: 0.0,
              totalTransportFeeInr: 0.0,
              commodityCostInr: 0.0,
              totalPayableInr: 0.0,
              statutoryNotice: 'Self-collection at FPS is 100% free of charge.',
            ),
    );
  }
}

class CitizenDeliveryRecord {
  final int id;
  final String requestId;
  final String beneficiaryId;
  final String cycleId;
  final String commodity;
  final double requestedQuantityKg;
  final double authorizedQuantityKg;
  final String deliveryMode;
  final String? deliveryAddress;
  final double deliveryDistanceKm;
  final double transportFeeInr;
  final String deliveryStatus;
  final double receivedRiceKg;
  final double receivedWheatKg;
  final String? citizenConfirmedAt;
  final String? disputeReason;
  final String status;
  final String? registeredFpsId;
  final String? registeredFpsName;
  final String? intendedFpsId;
  final String? intendedFpsName;
  final String createdAt;

  CitizenDeliveryRecord({
    required this.id,
    required this.requestId,
    required this.beneficiaryId,
    required this.cycleId,
    required this.commodity,
    required this.requestedQuantityKg,
    required this.authorizedQuantityKg,
    required this.deliveryMode,
    this.deliveryAddress,
    required this.deliveryDistanceKm,
    required this.transportFeeInr,
    required this.deliveryStatus,
    required this.receivedRiceKg,
    required this.receivedWheatKg,
    this.citizenConfirmedAt,
    this.disputeReason,
    required this.status,
    this.registeredFpsId,
    this.registeredFpsName,
    this.intendedFpsId,
    this.intendedFpsName,
    required this.createdAt,
  });

  factory CitizenDeliveryRecord.fromJson(Map<String, dynamic> json) {
    return CitizenDeliveryRecord(
      id: json['id'] ?? 0,
      requestId: json['request_id'] ?? '',
      beneficiaryId: json['beneficiary_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      commodity: json['commodity'] ?? 'Rice',
      requestedQuantityKg: (json['requested_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      authorizedQuantityKg: (json['authorized_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      deliveryMode: json['delivery_mode'] ?? 'FPS_COLLECTION',
      deliveryAddress: json['delivery_address'],
      deliveryDistanceKm: (json['delivery_distance_km'] as num?)?.toDouble() ?? 0.0,
      transportFeeInr: (json['transport_fee_inr'] as num?)?.toDouble() ?? 0.0,
      deliveryStatus: json['delivery_status'] ?? 'SERVICE_REQUESTED',
      receivedRiceKg: (json['received_rice_kg'] as num?)?.toDouble() ?? 0.0,
      receivedWheatKg: (json['received_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      citizenConfirmedAt: json['citizen_confirmed_at'],
      disputeReason: json['dispute_reason'],
      status: json['status'] ?? 'PENDING_OFFICER_REVIEW',
      registeredFpsId: json['registered_fps_id'],
      registeredFpsName: json['registered_fps_name'],
      intendedFpsId: json['intended_fps_id'],
      intendedFpsName: json['intended_fps_name'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class DeliveryDisputeModel {
  final int id;
  final String disputeId;
  final String requestId;
  final String beneficiaryId;
  final String cycleId;
  final String commodity;
  final double allocatedQuantityKg;
  final double receivedQuantityKg;
  final double shortfallKg;
  final String disputeNotes;
  final String status;
  final String? resolutionNotes;
  final String? resolvedBy;
  final String? resolvedAt;
  final String createdAt;

  DeliveryDisputeModel({
    required this.id,
    required this.disputeId,
    required this.requestId,
    required this.beneficiaryId,
    required this.cycleId,
    required this.commodity,
    required this.allocatedQuantityKg,
    required this.receivedQuantityKg,
    required this.shortfallKg,
    required this.disputeNotes,
    required this.status,
    this.resolutionNotes,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
  });

  factory DeliveryDisputeModel.fromJson(Map<String, dynamic> json) {
    return DeliveryDisputeModel(
      id: json['id'] ?? 0,
      disputeId: json['dispute_id'] ?? '',
      requestId: json['request_id'] ?? '',
      beneficiaryId: json['beneficiary_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      commodity: json['commodity'] ?? 'Rice',
      allocatedQuantityKg: (json['allocated_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      receivedQuantityKg: (json['received_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      shortfallKg: (json['shortfall_kg'] as num?)?.toDouble() ?? 0.0,
      disputeNotes: json['dispute_notes'] ?? '',
      status: json['status'] ?? 'PENDING_OFFICER_REVIEW',
      resolutionNotes: json['resolution_notes'],
      resolvedBy: json['resolved_by'],
      resolvedAt: json['resolved_at'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

