/// Strongly-typed Data Transfer Models for Fair Price Shop (FPS) Owner Command Center
/// Government of Karnataka • Department of Food and Civil Supplies

class FpsOwnerProfile {
  final String fpsId;
  final String name;
  final String district;
  final double latitude;
  final double longitude;
  final double capacityKg;
  final int beneficiariesCount;
  final String activeCycle;
  final String operatingStatus;
  final String dealerName;
  final String dealerPhone;
  final String assignedDepot;
  final String operatingHours;
  final String authenticatedUser;
  final String role;

  const FpsOwnerProfile({
    required this.fpsId,
    required this.name,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.capacityKg,
    required this.beneficiariesCount,
    required this.activeCycle,
    required this.operatingStatus,
    required this.dealerName,
    required this.dealerPhone,
    required this.assignedDepot,
    required this.operatingHours,
    required this.authenticatedUser,
    required this.role,
  });

  factory FpsOwnerProfile.fromJson(Map<String, dynamic> json) {
    return FpsOwnerProfile(
      fpsId: json['fps_id'] ?? '',
      name: json['name'] ?? '',
      district: json['district'] ?? 'Bengaluru Urban',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 12.9716,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.5946,
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 5000.0,
      beneficiariesCount: json['beneficiaries_count'] ?? 100,
      activeCycle: json['active_cycle'] ?? '2026-09',
      operatingStatus: json['operating_status'] ?? 'CLOSED',
      dealerName: json['dealer_name'] ?? 'Authorized Dealer',
      dealerPhone: json['dealer_phone'] ?? '+91-98450-88123',
      assignedDepot: json['assigned_depot'] ?? 'Bengaluru Central FCI Godown (Hebbal)',
      operatingHours: json['operating_hours'] ?? '08:00 AM - 08:00 PM',
      authenticatedUser: json['authenticated_user'] ?? 'fps_user',
      role: json['role'] ?? 'FPS_OWNER',
    );
  }
}

class FpsDashboardKpis {
  final int totalBeneficiaries;
  final int servedBeneficiaries;
  final int pendingBeneficiaries;
  final double currentRiceStockKg;
  final double currentWheatStockKg;
  final double currentSugarStockKg;
  final double currentKeroseneL;
  final double todayDistributedRiceKg;
  final double todayDistributedWheatKg;
  final int todayTransactionsCount;
  final double cycleDistributedRiceKg;
  final double cycleDistributedWheatKg;
  final int cycleTransactionsCount;
  final int pendingDeliveriesCount;
  final double stockDaysRemaining;
  final int openExceptionsCount;

  const FpsDashboardKpis({
    required this.totalBeneficiaries,
    required this.servedBeneficiaries,
    required this.pendingBeneficiaries,
    required this.currentRiceStockKg,
    required this.currentWheatStockKg,
    required this.currentSugarStockKg,
    required this.currentKeroseneL,
    required this.todayDistributedRiceKg,
    required this.todayDistributedWheatKg,
    required this.todayTransactionsCount,
    required this.cycleDistributedRiceKg,
    required this.cycleDistributedWheatKg,
    required this.cycleTransactionsCount,
    required this.pendingDeliveriesCount,
    required this.stockDaysRemaining,
    required this.openExceptionsCount,
  });

  factory FpsDashboardKpis.fromJson(Map<String, dynamic> json) {
    return FpsDashboardKpis(
      totalBeneficiaries: json['total_beneficiaries'] ?? 100,
      servedBeneficiaries: json['served_beneficiaries'] ?? 0,
      pendingBeneficiaries: json['pending_beneficiaries'] ?? 100,
      currentRiceStockKg: (json['current_rice_stock_kg'] as num?)?.toDouble() ?? 0.0,
      currentWheatStockKg: (json['current_wheat_stock_kg'] as num?)?.toDouble() ?? 0.0,
      currentSugarStockKg: (json['current_sugar_stock_kg'] as num?)?.toDouble() ?? 0.0,
      currentKeroseneL: (json['current_kerosene_l'] as num?)?.toDouble() ?? 0.0,
      todayDistributedRiceKg: (json['today_distributed_rice_kg'] as num?)?.toDouble() ?? 0.0,
      todayDistributedWheatKg: (json['today_distributed_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      todayTransactionsCount: json['today_transactions_count'] ?? 0,
      cycleDistributedRiceKg: (json['cycle_distributed_rice_kg'] as num?)?.toDouble() ?? 0.0,
      cycleDistributedWheatKg: (json['cycle_distributed_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      cycleTransactionsCount: json['cycle_transactions_count'] ?? 0,
      pendingDeliveriesCount: json['pending_deliveries_count'] ?? 0,
      stockDaysRemaining: (json['stock_days_remaining'] as num?)?.toDouble() ?? 0.0,
      openExceptionsCount: json['open_exceptions_count'] ?? 0,
    );
  }
}

class FpsAttentionItem {
  final String id;
  final String type;
  final String severity;
  final String title;
  final String description;
  final String action;

  const FpsAttentionItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.action,
  });

  factory FpsAttentionItem.fromJson(Map<String, dynamic> json) {
    return FpsAttentionItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'GENERAL',
      severity: json['severity'] ?? 'MEDIUM',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      action: json['action'] ?? 'VIEW',
    );
  }
}

class FpsDashboardOverview {
  final String fpsId;
  final String cycleId;
  final String shopStatus;
  final FpsDashboardKpis kpis;
  final List<FpsAttentionItem> attentionItems;

  const FpsDashboardOverview({
    required this.fpsId,
    required this.cycleId,
    required this.shopStatus,
    required this.kpis,
    required this.attentionItems,
  });

  factory FpsDashboardOverview.fromJson(Map<String, dynamic> json) {
    final rawAttn = (json['attention_items'] as List<dynamic>?) ?? [];
    return FpsDashboardOverview(
      fpsId: json['fps_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      shopStatus: json['shop_status'] ?? 'CLOSED',
      kpis: FpsDashboardKpis.fromJson(json['kpis'] as Map<String, dynamic>? ?? {}),
      attentionItems: rawAttn.map((e) => FpsAttentionItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class FpsBeneficiaryRecord {
  final String beneficiaryId;
  final String name;
  final String phone;
  final String schemeType;
  final int membersCount;
  final double statutoryRiceKg;
  final double statutoryWheatKg;
  final double statutoryTotalKg;
  final bool isCollected;
  final String? collectedAt;
  final double receivedRiceKg;
  final double receivedWheatKg;
  final double remainingRiceKg;
  final double remainingWheatKg;

  const FpsBeneficiaryRecord({
    required this.beneficiaryId,
    required this.name,
    required this.phone,
    required this.schemeType,
    required this.membersCount,
    required this.statutoryRiceKg,
    required this.statutoryWheatKg,
    required this.statutoryTotalKg,
    required this.isCollected,
    this.collectedAt,
    required this.receivedRiceKg,
    required this.receivedWheatKg,
    required this.remainingRiceKg,
    required this.remainingWheatKg,
  });

  factory FpsBeneficiaryRecord.fromJson(Map<String, dynamic> json) {
    return FpsBeneficiaryRecord(
      beneficiaryId: json['beneficiary_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? 'N/A',
      schemeType: json['scheme_type'] ?? 'PHH',
      membersCount: json['members_count'] ?? 4,
      statutoryRiceKg: (json['statutory_rice_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryWheatKg: (json['statutory_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryTotalKg: (json['statutory_total_kg'] as num?)?.toDouble() ?? 0.0,
      isCollected: json['is_collected'] ?? false,
      collectedAt: json['collected_at'],
      receivedRiceKg: (json['received_rice_kg'] as num?)?.toDouble() ?? 0.0,
      receivedWheatKg: (json['received_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      remainingRiceKg: (json['remaining_rice_kg'] as num?)?.toDouble() ?? 0.0,
      remainingWheatKg: (json['remaining_wheat_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FpsInboundDelivery {
  final String gatepassId;
  final String truckId;
  final String manifestId;
  final String driverName;
  final String driverPhone;
  final String sourceDepot;
  final String destinationFpsId;
  final double dispatchedRiceKg;
  final double dispatchedWheatKg;
  final double totalPayloadKg;
  final String status;
  final String? issuedAt;
  final String? verifiedAt;
  final double? currentLat;
  final double? currentLon;
  final bool liveTrackingAvailable;

  const FpsInboundDelivery({
    required this.gatepassId,
    required this.truckId,
    required this.manifestId,
    required this.driverName,
    required this.driverPhone,
    required this.sourceDepot,
    required this.destinationFpsId,
    required this.dispatchedRiceKg,
    required this.dispatchedWheatKg,
    required this.totalPayloadKg,
    required this.status,
    this.issuedAt,
    this.verifiedAt,
    this.currentLat,
    this.currentLon,
    required this.liveTrackingAvailable,
  });

  factory FpsInboundDelivery.fromJson(Map<String, dynamic> json) {
    return FpsInboundDelivery(
      gatepassId: json['gatepass_id'] ?? '',
      truckId: json['truck_id'] ?? '',
      manifestId: json['manifest_id'] ?? '',
      driverName: json['driver_name'] ?? 'Ramesh Kumar',
      driverPhone: json['driver_phone'] ?? '+91-98450-12345',
      sourceDepot: json['source_depot'] ?? 'Bengaluru Central FCI Godown (Hebbal)',
      destinationFpsId: json['destination_fps_id'] ?? '',
      dispatchedRiceKg: (json['dispatched_rice_kg'] as num?)?.toDouble() ?? 0.0,
      dispatchedWheatKg: (json['dispatched_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      totalPayloadKg: (json['total_payload_kg'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'IN_TRANSIT',
      issuedAt: json['issued_at'],
      verifiedAt: json['verified_at'],
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLon: (json['current_lon'] as num?)?.toDouble(),
      liveTrackingAvailable: json['live_tracking_available'] ?? false,
    );
  }
}

class FpsAiInsight {
  final String id;
  final String category;
  final String severity;
  final String title;
  final String summary;
  final String why;
  final Map<String, dynamic> evidence;
  final String recommendation;
  final String action;

  const FpsAiInsight({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.summary,
    required this.why,
    required this.evidence,
    required this.recommendation,
    required this.action,
  });

  factory FpsAiInsight.fromJson(Map<String, dynamic> json) {
    return FpsAiInsight(
      id: json['id'] ?? '',
      category: json['category'] ?? 'INSIGHT',
      severity: json['severity'] ?? 'LOW',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      why: json['why'] ?? '',
      evidence: (json['evidence'] as Map<String, dynamic>?) ?? {},
      recommendation: json['recommendation'] ?? '',
      action: json['action'] ?? 'VIEW',
    );
  }
}

class FpsExceptionItem {
  final String exceptionId;
  final String fpsId;
  final String category;
  final String severity;
  final String title;
  final String description;
  final String status;
  final bool dsoNotified;
  final String createdAt;
  final String? resolvedAt;

  const FpsExceptionItem({
    required this.exceptionId,
    required this.fpsId,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.status,
    required this.dsoNotified,
    required this.createdAt,
    this.resolvedAt,
  });

  factory FpsExceptionItem.fromJson(Map<String, dynamic> json) {
    return FpsExceptionItem(
      exceptionId: json['exception_id'] ?? '',
      fpsId: json['fps_id'] ?? '',
      category: json['category'] ?? 'OPERATIONAL',
      severity: json['severity'] ?? 'MEDIUM',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'OPEN',
      dsoNotified: json['dso_notified'] == 1 || json['dso_notified'] == true,
      createdAt: json['created_at'] ?? '',
      resolvedAt: json['resolved_at'],
    );
  }
}

class FpsDecisionTraceEvent {
  final String timestamp;
  final String eventType;
  final String actor;
  final String action;
  final String details;

  const FpsDecisionTraceEvent({
    required this.timestamp,
    required this.eventType,
    required this.actor,
    required this.action,
    required this.details,
  });

  factory FpsDecisionTraceEvent.fromJson(Map<String, dynamic> json) {
    return FpsDecisionTraceEvent(
      timestamp: json['timestamp'] ?? '',
      eventType: json['event_type'] ?? 'EVENT',
      actor: json['actor'] ?? 'System',
      action: json['action'] ?? '',
      details: json['details'] ?? '',
    );
  }
}

class FpsDataSourceItem {
  final String tableName;
  final String description;
  final String database;
  final int totalRecords;
  final String fpsFilter;
  final String lastSynced;

  const FpsDataSourceItem({
    required this.tableName,
    required this.description,
    required this.database,
    required this.totalRecords,
    required this.fpsFilter,
    required this.lastSynced,
  });

  factory FpsDataSourceItem.fromJson(Map<String, dynamic> json) {
    return FpsDataSourceItem(
      tableName: json['table_name'] ?? '',
      description: json['description'] ?? '',
      database: json['database'] ?? 'SQLite',
      totalRecords: json['total_records'] ?? 0,
      fpsFilter: json['fps_filter'] ?? '',
      lastSynced: json['last_synced'] ?? '',
    );
  }
}

class FpsEposEligibility {
  final String beneficiaryId;
  final String name;
  final String registeredFpsId;
  final String registeredFpsName;
  final String cardType;
  final String categoryLabel;
  final int familyMembersCount;
  final double statutoryRiceKg;
  final double statutoryWheatKg;
  final bool alreadyCollected;
  final String? collectedAt;
  final bool isPortability;

  const FpsEposEligibility({
    required this.beneficiaryId,
    required this.name,
    required this.registeredFpsId,
    required this.registeredFpsName,
    required this.cardType,
    required this.categoryLabel,
    required this.familyMembersCount,
    required this.statutoryRiceKg,
    required this.statutoryWheatKg,
    required this.alreadyCollected,
    this.collectedAt,
    required this.isPortability,
  });

  factory FpsEposEligibility.fromJson(Map<String, dynamic> json) {
    return FpsEposEligibility(
      beneficiaryId: json['beneficiary_id'] ?? '',
      name: json['name'] ?? '',
      registeredFpsId: json['registered_fps_id'] ?? '',
      registeredFpsName: json['registered_fps_name'] ?? 'Registered Fair Price Shop',
      cardType: json['card_type'] ?? 'PHH',
      categoryLabel: json['category_label'] ?? 'Priority Household (BPHH / PHH)',
      familyMembersCount: json['family_members_count'] ?? 1,
      statutoryRiceKg: (json['statutory_rice_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryWheatKg: (json['statutory_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      alreadyCollected: json['already_collected'] ?? false,
      collectedAt: json['collected_at'],
      isPortability: json['is_portability'] ?? false,
    );
  }
}

class FpsEposDispenseResult {
  final String transactionId;
  final String beneficiaryId;
  final String fpsId;
  final String cycleId;
  final double riceDispensedKg;
  final double wheatDispensedKg;
  final double remainingFpsRiceStockKg;
  final double remainingFpsWheatStockKg;
  final String status;
  final String receiptConfirmedAt;

  const FpsEposDispenseResult({
    required this.transactionId,
    required this.beneficiaryId,
    required this.fpsId,
    required this.cycleId,
    required this.riceDispensedKg,
    required this.wheatDispensedKg,
    required this.remainingFpsRiceStockKg,
    required this.remainingFpsWheatStockKg,
    required this.status,
    required this.receiptConfirmedAt,
  });

  factory FpsEposDispenseResult.fromJson(Map<String, dynamic> json) {
    return FpsEposDispenseResult(
      transactionId: json['transaction_id'] ?? '',
      beneficiaryId: json['beneficiary_id'] ?? '',
      fpsId: json['fps_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      riceDispensedKg: (json['rice_dispensed_kg'] as num?)?.toDouble() ?? 0.0,
      wheatDispensedKg: (json['wheat_dispensed_kg'] as num?)?.toDouble() ?? 0.0,
      remainingFpsRiceStockKg: (json['remaining_fps_rice_stock_kg'] as num?)?.toDouble() ?? 0.0,
      remainingFpsWheatStockKg: (json['remaining_fps_wheat_stock_kg'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'SUCCESS_DISPENSED',
      receiptConfirmedAt: json['receipt_confirmed_at'] ?? '',
    );
  }
}
