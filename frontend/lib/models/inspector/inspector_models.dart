/// Strongly-typed Data Transfer Models for Field Food Inspector Command Center
/// Government of Karnataka • Department of Food and Civil Supplies

class InspectorStats {
  final int totalInspections;
  final int compliantCount;
  final int nonCompliantCount;
  final int pendingAssignments;
  final int seizureNotices;
  final double averageComplianceScore;
  final int sealedRecordsCount;

  const InspectorStats({
    required this.totalInspections,
    required this.compliantCount,
    required this.nonCompliantCount,
    required this.pendingAssignments,
    required this.seizureNotices,
    required this.averageComplianceScore,
    required this.sealedRecordsCount,
  });

  factory InspectorStats.fromJson(Map<String, dynamic> json) {
    return InspectorStats(
      totalInspections: json['total_inspections'] ?? 0,
      compliantCount: json['compliant_count'] ?? 0,
      nonCompliantCount: json['non_compliant_count'] ?? 0,
      pendingAssignments: json['pending_assignments'] ?? 0,
      seizureNotices: json['seizure_notices'] ?? 0,
      averageComplianceScore: (json['average_compliance_score'] as num?)?.toDouble() ?? 100.0,
      sealedRecordsCount: json['sealed_records_count'] ?? 0,
    );
  }
}

class InspectorOfficerProfile {
  final String username;
  final String role;
  final String district;
  final String status;

  const InspectorOfficerProfile({
    required this.username,
    required this.role,
    required this.district,
    required this.status,
  });

  factory InspectorOfficerProfile.fromJson(Map<String, dynamic> json) {
    return InspectorOfficerProfile(
      username: json['username'] ?? 'inspector_user',
      role: json['role'] ?? 'FIELD_FOOD_INSPECTOR',
      district: json['district'] ?? 'Bengaluru Urban',
      status: json['status'] ?? 'OPERATIONAL',
    );
  }
}

class InspectorTarget {
  final String fpsId;
  final String name;
  final String district;
  final double latitude;
  final double longitude;
  final int beneficiariesCount;
  final double capacityKg;
  final String? orderId;
  final String? priority;
  final String? reason;
  final String? orderStatus;
  final String? assignedAt;
  final double riceStockKg;
  final double wheatStockKg;
  final int previousInspectionsCount;
  final double? lastComplianceScore;

  const InspectorTarget({
    required this.fpsId,
    required this.name,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.beneficiariesCount,
    required this.capacityKg,
    this.orderId,
    this.priority,
    this.reason,
    this.orderStatus,
    this.assignedAt,
    required this.riceStockKg,
    required this.wheatStockKg,
    required this.previousInspectionsCount,
    this.lastComplianceScore,
  });

  factory InspectorTarget.fromJson(Map<String, dynamic> json) {
    return InspectorTarget(
      fpsId: json['fps_id'] ?? '',
      name: json['name'] ?? json['fps_name'] ?? json['fps_id'] ?? '',
      district: json['district'] ?? json['fps_district'] ?? 'Bengaluru Urban',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 12.9716,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.5946,
      beneficiariesCount: json['beneficiaries_count'] ?? 100,
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 5000.0,
      orderId: json['order_id'],
      priority: json['priority'],
      reason: json['reason'],
      orderStatus: json['order_status'] ?? json['status'],
      assignedAt: json['assigned_at'] ?? json['created_at'],
      riceStockKg: (json['rice_stock_kg'] as num?)?.toDouble() ?? 0.0,
      wheatStockKg: (json['wheat_stock_kg'] as num?)?.toDouble() ?? 0.0,
      previousInspectionsCount: json['previous_inspections_count'] ?? 0,
      lastComplianceScore: (json['last_compliance_score'] as num?)?.toDouble(),
    );
  }
}

class InboundDispatchInfo {
  final String truckId;
  final String vehicleModel;
  final String manifestId;
  final String dispatchId;
  final String driverName;
  final String driverPhone;
  final String originDepotName;
  final double originLat;
  final double originLon;
  final String destinationFpsId;
  final String destinationFpsName;
  final double destinationLat;
  final double destinationLon;
  final String commodity;
  final double allocatedQuantityKg;
  final double dispatchedQuantityKg;
  final String gatepassId;
  final String currentStatus;
  final double currentLat;
  final double currentLon;
  final double speedKmh;
  final double distanceTravelledKm;
  final double distanceRemainingKm;
  final double totalRouteDistanceKm;
  final int etaMinutes;
  final String expectedArrivalTime;
  final String lastTelemetryTime;
  final String telemetryStatus;
  final String routeName;
  final List<dynamic> routeStops;
  final List<dynamic> dispatchTimeline;
  final List<dynamic> multiFpsStops;
  final bool isWithinGeofence;
  final double distanceToFpsM;
  final bool isArrivalVerified;
  final String movementApprovalStatus;
  final String? movementClearanceToken;
  final bool canApproveMovement;

  const InboundDispatchInfo({
    required this.truckId,
    required this.vehicleModel,
    required this.manifestId,
    required this.dispatchId,
    required this.driverName,
    required this.driverPhone,
    required this.originDepotName,
    required this.originLat,
    required this.originLon,
    required this.destinationFpsId,
    required this.destinationFpsName,
    required this.destinationLat,
    required this.destinationLon,
    required this.commodity,
    required this.allocatedQuantityKg,
    required this.dispatchedQuantityKg,
    required this.gatepassId,
    required this.currentStatus,
    required this.currentLat,
    required this.currentLon,
    required this.speedKmh,
    required this.distanceTravelledKm,
    required this.distanceRemainingKm,
    required this.totalRouteDistanceKm,
    required this.etaMinutes,
    required this.expectedArrivalTime,
    required this.lastTelemetryTime,
    required this.telemetryStatus,
    required this.routeName,
    required this.routeStops,
    required this.dispatchTimeline,
    required this.multiFpsStops,
    required this.isWithinGeofence,
    required this.distanceToFpsM,
    required this.isArrivalVerified,
    required this.movementApprovalStatus,
    this.movementClearanceToken,
    required this.canApproveMovement,
  });

  factory InboundDispatchInfo.fromJson(Map<String, dynamic> json) {
    return InboundDispatchInfo(
      truckId: json['truck_id'] ?? 'TRK-KA-04-E-1024',
      vehicleModel: json['vehicle_model'] ?? 'Tata Ultra 10 MT Heavy Logistics',
      manifestId: json['manifest_id'] ?? 'MAN-2026-0914',
      dispatchId: json['dispatch_id'] ?? 'DSP-202609-1024',
      driverName: json['driver_name'] ?? 'Ramesh Kumar',
      driverPhone: json['driver_phone'] ?? '+91-9845012345',
      originDepotName: json['origin_depot_name'] ?? 'Bengaluru Central FCI Godown (Hebbal)',
      originLat: (json['origin_lat'] as num?)?.toDouble() ?? 13.0358,
      originLon: (json['origin_lon'] as num?)?.toDouble() ?? 77.5970,
      destinationFpsId: json['destination_fps_id'] ?? '',
      destinationFpsName: json['destination_fps_name'] ?? '',
      destinationLat: (json['destination_lat'] as num?)?.toDouble() ?? 12.9716,
      destinationLon: (json['destination_lon'] as num?)?.toDouble() ?? 77.5946,
      commodity: json['commodity'] ?? 'Rice',
      allocatedQuantityKg: (json['allocated_quantity_kg'] as num?)?.toDouble() ?? 2450.0,
      dispatchedQuantityKg: (json['dispatched_quantity_kg'] as num?)?.toDouble() ?? 2450.0,
      gatepassId: json['gatepass_id'] ?? 'GP-BLR-0914',
      currentStatus: json['current_status'] ?? 'IN_TRANSIT',
      currentLat: (json['current_lat'] as num?)?.toDouble() ?? 12.9716,
      currentLon: (json['current_lon'] as num?)?.toDouble() ?? 77.5946,
      speedKmh: (json['speed_kmh'] as num?)?.toDouble() ?? 35.0,
      distanceTravelledKm: (json['distance_travelled_km'] as num?)?.toDouble() ?? 5.0,
      distanceRemainingKm: (json['distance_remaining_km'] as num?)?.toDouble() ?? 8.0,
      totalRouteDistanceKm: (json['total_route_distance_km'] as num?)?.toDouble() ?? 13.0,
      etaMinutes: json['eta_minutes'] ?? 25,
      expectedArrivalTime: json['expected_arrival_time'] ?? '10:30 AM',
      lastTelemetryTime: json['last_telemetry_time'] ?? '',
      telemetryStatus: json['telemetry_status'] ?? 'LIVE',
      routeName: json['route_name'] ?? 'Hebbal to City Center Corridor',
      routeStops: json['route_stops'] ?? [],
      dispatchTimeline: json['dispatch_timeline'] ?? [],
      multiFpsStops: json['multi_fps_stops'] ?? [],
      isWithinGeofence: json['geofence_status'] == 'WITHIN_GEOFENCE',
      distanceToFpsM: (json['distance_to_fps_m'] as num?)?.toDouble() ?? 250.0,
      isArrivalVerified: json['is_arrival_verified'] ?? false,
      movementApprovalStatus: json['movement_approval_status'] ?? 'PENDING_APPROVAL',
      movementClearanceToken: json['movement_clearance_token'],
      canApproveMovement: json['can_approve_movement'] ?? false,
    );
  }
}

class GeofenceVerifyResult {
  final bool verified;
  final String status;
  final double distanceM;
  final double statutoryRadiusM;
  final String fpsName;
  final String verifiedBy;
  final String timestamp;
  final String message;

  const GeofenceVerifyResult({
    required this.verified,
    required this.status,
    required this.distanceM,
    required this.statutoryRadiusM,
    required this.fpsName,
    required this.verifiedBy,
    required this.timestamp,
    required this.message,
  });

  factory GeofenceVerifyResult.fromJson(Map<String, dynamic> json) {
    return GeofenceVerifyResult(
      verified: json['verified'] ?? (json['geofence_status'] == 'WITHIN_GEOFENCE'),
      status: json['geofence_status'] ?? 'WITHIN_GEOFENCE',
      distanceM: (json['distance_meters'] as num?)?.toDouble() ?? (json['distance_m'] as num?)?.toDouble() ?? 24.5,
      statutoryRadiusM: (json['statutory_radius_m'] as num?)?.toDouble() ?? 50.0,
      fpsName: json['fps_name'] ?? '',
      verifiedBy: json['verified_by'] ?? 'inspector_user',
      timestamp: json['verified_at'] ?? json['timestamp'] ?? '',
      message: json['message'] ?? 'Physical arrival verified within Fair Price Shop 50m perimeter.',
    );
  }
}

class EvidenceItem {
  final String id;
  final String type;
  final String description;
  final String referencePath;
  final String timestamp;
  final String inspector;

  const EvidenceItem({
    required this.id,
    required this.type,
    required this.description,
    required this.referencePath,
    required this.timestamp,
    required this.inspector,
  });

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    return EvidenceItem(
      id: json['evidence_id'] ?? json['id'] ?? '',
      type: json['evidence_type'] ?? json['type'] ?? 'PHOTOGRAPH',
      description: json['description'] ?? '',
      referencePath: json['reference_path'] ?? json['path'] ?? '',
      timestamp: json['created_at'] ?? json['timestamp'] ?? '',
      inspector: json['inspector_id'] ?? json['inspector'] ?? 'inspector_user',
    );
  }
}

class SealedInspectionReport {
  final String inspectionId;
  final String fpsId;
  final String fpsName;
  final String district;
  final String inspectorId;
  final double complianceScore;
  final String status;
  final String sealedHash;
  final String sealedAt;
  final String remarks;
  final double? observedRiceKg;
  final double? observedWheatKg;
  final double? riceDiffKg;
  final double? wheatDiffKg;
  final double? moisturePct;
  final double? scaleErrorG;
  final bool seizureIssued;
  final String? seizureReason;
  final List<EvidenceItem> evidence;

  const SealedInspectionReport({
    required this.inspectionId,
    required this.fpsId,
    required this.fpsName,
    required this.district,
    required this.inspectorId,
    required this.complianceScore,
    required this.status,
    required this.sealedHash,
    required this.sealedAt,
    required this.remarks,
    this.observedRiceKg,
    this.observedWheatKg,
    this.riceDiffKg,
    this.wheatDiffKg,
    this.moisturePct,
    this.scaleErrorG,
    required this.seizureIssued,
    this.seizureReason,
    required this.evidence,
  });

  factory SealedInspectionReport.fromJson(Map<String, dynamic> json) {
    final rep = json['report'] ?? json;
    final rawEv = (json['evidence'] as List<dynamic>?) ?? [];
    return SealedInspectionReport(
      inspectionId: rep['inspection_id'] ?? '',
      fpsId: rep['fps_id'] ?? '',
      fpsName: rep['fps_name'] ?? rep['fps_id'] ?? '',
      district: rep['fps_district'] ?? 'Bengaluru Urban',
      inspectorId: rep['inspector_id'] ?? 'inspector_user',
      complianceScore: (rep['compliance_score'] as num?)?.toDouble() ?? 100.0,
      status: rep['status'] ?? 'SEALED',
      sealedHash: rep['sealed_hash'] ?? '',
      sealedAt: rep['sealed_at'] ?? rep['created_at'] ?? '',
      remarks: rep['remarks'] ?? '',
      observedRiceKg: (rep['observed_rice_kg'] as num?)?.toDouble(),
      observedWheatKg: (rep['observed_wheat_kg'] as num?)?.toDouble(),
      riceDiffKg: (rep['rice_diff_kg'] as num?)?.toDouble(),
      wheatDiffKg: (rep['wheat_diff_kg'] as num?)?.toDouble(),
      moisturePct: (rep['moisture_pct'] as num?)?.toDouble() ?? (rep['moisture_percentage'] as num?)?.toDouble(),
      scaleErrorG: (rep['scale_error_g'] as num?)?.toDouble() ?? (rep['scale_error_grams'] as num?)?.toDouble(),
      seizureIssued: rep['seizure_issued'] == 1 || rep['issue_seizure_notice'] == 1,
      seizureReason: rep['seizure_reason'],
      evidence: rawEv.map((e) => EvidenceItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class InspectorAiInsight {
  final String title;
  final String type;
  final String fps;
  final String why;
  final String evidence;
  final String confidence;

  const InspectorAiInsight({
    required this.title,
    required this.type,
    required this.fps,
    required this.why,
    required this.evidence,
    required this.confidence,
  });

  factory InspectorAiInsight.fromJson(Map<String, dynamic> json) {
    return InspectorAiInsight(
      title: json['title'] ?? '',
      type: json['type'] ?? 'INSIGHT',
      fps: json['fps'] ?? '',
      why: json['why'] ?? '',
      evidence: json['evidence'] ?? '',
      confidence: json['confidence'] ?? 'Data-backed',
    );
  }
}

class InspectorAnomalyItem {
  final String fpsId;
  final String fpsName;
  final String type;
  final String severity;
  final double zScore;
  final double totalDeclaredKg;
  final String details;
  final String action;

  const InspectorAnomalyItem({
    required this.fpsId,
    required this.fpsName,
    required this.type,
    required this.severity,
    required this.zScore,
    required this.totalDeclaredKg,
    required this.details,
    required this.action,
  });

  factory InspectorAnomalyItem.fromJson(Map<String, dynamic> json) {
    return InspectorAnomalyItem(
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? json['fps_id'] ?? '',
      type: json['type'] ?? 'ANOMALY',
      severity: json['severity'] ?? 'HIGH',
      zScore: (json['z_score'] as num?)?.toDouble() ?? 2.0,
      totalDeclaredKg: (json['total_declared_kg'] as num?)?.toDouble() ?? 0.0,
      details: json['details'] ?? '',
      action: json['action'] ?? 'VERIFY_ON_SITE',
    );
  }
}

class InspectorRecommendationItem {
  final String orderId;
  final String fpsId;
  final String fpsName;
  final String priority;
  final String recommendation;
  final String reason;
  final List<String> focusAreas;

  const InspectorRecommendationItem({
    required this.orderId,
    required this.fpsId,
    required this.fpsName,
    required this.priority,
    required this.recommendation,
    required this.reason,
    required this.focusAreas,
  });

  factory InspectorRecommendationItem.fromJson(Map<String, dynamic> json) {
    return InspectorRecommendationItem(
      orderId: json['order_id'] ?? '',
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? json['fps_id'] ?? '',
      priority: json['priority'] ?? 'HIGH',
      recommendation: json['recommendation'] ?? '',
      reason: json['reason'] ?? '',
      focusAreas: (json['focus_areas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class InspectorExceptionItem {
  final String id;
  final String type;
  final String fps;
  final String severity;
  final String details;
  final String detectedAt;
  final String source;
  final String action;

  const InspectorExceptionItem({
    required this.id,
    required this.type,
    required this.fps,
    required this.severity,
    required this.details,
    required this.detectedAt,
    required this.source,
    required this.action,
  });

  factory InspectorExceptionItem.fromJson(Map<String, dynamic> json) {
    return InspectorExceptionItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'EXCEPTION',
      fps: json['fps'] ?? '',
      severity: json['severity'] ?? 'HIGH',
      details: json['details'] ?? '',
      detectedAt: json['detected_at'] ?? '',
      source: json['source'] ?? 'System',
      action: json['action'] ?? 'Inspect',
    );
  }
}

class InspectorDecisionTraceEvent {
  final String eventId;
  final String eventType;
  final String action;
  final String entityType;
  final String entityId;
  final String actorName;
  final String actorRole;
  final String? notes;
  final String timestamp;

  const InspectorDecisionTraceEvent({
    required this.eventId,
    required this.eventType,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorName,
    required this.actorRole,
    this.notes,
    required this.timestamp,
  });

  factory InspectorDecisionTraceEvent.fromJson(Map<String, dynamic> json) {
    return InspectorDecisionTraceEvent(
      eventId: json['event_id'] ?? '',
      eventType: json['event_type'] ?? 'GOVERNANCE_EVENT',
      action: json['action'] ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'] ?? '',
      actorName: json['actor_name'] ?? '',
      actorRole: json['actor_role'] ?? 'FIELD_FOOD_INSPECTOR',
      notes: json['notes'],
      timestamp: json['timestamp'] ?? '',
    );
  }
}
