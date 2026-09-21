class MetricItem {
  final double count;
  final double? changePct;
  final String? label;
  final double? riceKg;
  final double? wheatKg;
  final int? totalFps;

  MetricItem({
    required this.count,
    this.changePct,
    this.label,
    this.riceKg,
    this.wheatKg,
    this.totalFps,
  });

  factory MetricItem.fromJson(Map<String, dynamic> json) {
    return MetricItem(
      count: (json['count'] as num?)?.toDouble() ?? 0.0,
      changePct: (json['change_pct'] as num?)?.toDouble(),
      label: json['label'] as String?,
      riceKg: (json['rice_kg'] as num?)?.toDouble(),
      wheatKg: (json['wheat_kg'] as num?)?.toDouble(),
      totalFps: json['total_fps'] as int?,
    );
  }
}

class DsoExceptionItem {
  final String id;
  final String type;
  final String fps;
  final String details;
  final String severity;
  final String detectedAt;
  final String action;

  DsoExceptionItem({
    required this.id,
    required this.type,
    required this.fps,
    required this.details,
    required this.severity,
    required this.detectedAt,
    required this.action,
  });

  factory DsoExceptionItem.fromJson(Map<String, dynamic> json) {
    return DsoExceptionItem(
      id: json['id'] ?? 'EXC-000',
      type: json['type'] ?? 'Unknown Exception',
      fps: json['fps'] ?? 'N/A',
      details: json['details'] ?? 'No details available',
      severity: json['severity'] ?? 'Medium',
      detectedAt: json['detected_at'] ?? 'Today',
      action: json['action'] ?? 'View',
    );
  }
}

class DsoAiInsightItem {
  final String id;
  final String title;
  final String summary;
  final String severity;
  final String why;
  final String evidence;

  DsoAiInsightItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.severity,
    required this.why,
    required this.evidence,
  });

  factory DsoAiInsightItem.fromJson(Map<String, dynamic> json) {
    return DsoAiInsightItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      severity: json['severity'] ?? 'Info',
      why: json['why'] ?? 'Analysis based on historical and intent signals.',
      evidence: json['evidence'] ?? 'Source: pds_demandsync.db',
    );
  }
}

class DsoCommandOverview {
  final String status;
  final String district;
  final String cycleId;
  final String currentStage;
  final Map<String, MetricItem> metrics;
  final Map<String, dynamic> demandBreakdown;
  final List<DsoExceptionItem> exceptions;
  final List<DsoAiInsightItem> aiInsights;
  final Map<String, dynamic> aiRecommendation;
  final String dataLastUpdated;

  DsoCommandOverview({
    required this.status,
    required this.district,
    required this.cycleId,
    required this.currentStage,
    required this.metrics,
    required this.demandBreakdown,
    required this.exceptions,
    required this.aiInsights,
    required this.aiRecommendation,
    required this.dataLastUpdated,
  });

  factory DsoCommandOverview.fromJson(Map<String, dynamic> json) {
    final mRaw = json['metrics'] as Map<String, dynamic>? ?? {};
    final metricsMap = <String, MetricItem>{};
    mRaw.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        metricsMap[key] = MetricItem.fromJson(val);
      }
    });

    final excList = (json['exceptions'] as List<dynamic>? ?? [])
        .map((e) => DsoExceptionItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final aiList = (json['ai_insights'] as List<dynamic>? ?? [])
        .map((e) => DsoAiInsightItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return DsoCommandOverview(
      status: json['status'] ?? 'success',
      district: json['district'] ?? 'Ramanagara',
      cycleId: json['cycle_id'] ?? '2026-09',
      currentStage: json['current_stage'] ?? 'FORECASTED',
      metrics: metricsMap,
      demandBreakdown: json['demand_breakdown'] as Map<String, dynamic>? ?? {},
      exceptions: excList,
      aiInsights: aiList,
      aiRecommendation: json['ai_recommendation'] as Map<String, dynamic>? ?? {},
      dataLastUpdated: json['data_last_updated'] ?? 'Today 12:32 PM',
    );
  }
}

class DsoAllocationItem {
  final String fpsId;
  final String name;
  final String commodity;
  final double validatedRequirementKg;
  final double existingStockKg;
  final double netRequirementKg;
  final double proposedAllocationKg;
  final double shortfallKg;
  final String priority;
  final bool isOverridden;
  final String? overrideReason;

  DsoAllocationItem({
    required this.fpsId,
    required this.name,
    required this.commodity,
    required this.validatedRequirementKg,
    required this.existingStockKg,
    required this.netRequirementKg,
    required this.proposedAllocationKg,
    required this.shortfallKg,
    required this.priority,
    required this.isOverridden,
    this.overrideReason,
  });

  factory DsoAllocationItem.fromJson(Map<String, dynamic> json) {
    return DsoAllocationItem(
      fpsId: json['fps_id'] ?? '',
      name: json['name'] ?? '',
      commodity: json['commodity'] ?? 'Rice',
      validatedRequirementKg: (json['validated_requirement_kg'] as num?)?.toDouble() ?? 0.0,
      existingStockKg: (json['existing_stock_kg'] as num?)?.toDouble() ?? 0.0,
      netRequirementKg: (json['net_requirement_kg'] as num?)?.toDouble() ?? 0.0,
      proposedAllocationKg: (json['proposed_allocation_kg'] as num?)?.toDouble() ?? 0.0,
      shortfallKg: (json['shortfall_kg'] as num?)?.toDouble() ?? 0.0,
      priority: json['priority'] ?? 'STATUTORY',
      isOverridden: json['is_overridden'] ?? false,
      overrideReason: json['override_reason'] as String?,
    );
  }
}

class DsoAllocationPlan {
  final String cycleId;
  final double availableDepotStockMt;
  final double totalValidatedDemandMt;
  final double totalExistingFpsStockMt;
  final double totalNetRequirementMt;
  final double totalProposedAllocationMt;
  final double totalShortfallMt;
  final double unallocatedDepotBalanceMt;
  final List<DsoAllocationItem> items;

  DsoAllocationPlan({
    required this.cycleId,
    required this.availableDepotStockMt,
    required this.totalValidatedDemandMt,
    required this.totalExistingFpsStockMt,
    required this.totalNetRequirementMt,
    required this.totalProposedAllocationMt,
    required this.totalShortfallMt,
    required this.unallocatedDepotBalanceMt,
    required this.items,
  });

  factory DsoAllocationPlan.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? [])
        .map((e) => DsoAllocationItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return DsoAllocationPlan(
      cycleId: json['cycle_id'] ?? '2026-09',
      availableDepotStockMt: (json['available_depot_stock_mt'] as num?)?.toDouble() ?? 850.0,
      totalValidatedDemandMt: (json['total_validated_demand_mt'] as num?)?.toDouble() ?? 276.7,
      totalExistingFpsStockMt: (json['total_existing_fps_stock_mt'] as num?)?.toDouble() ?? 24.5,
      totalNetRequirementMt: (json['total_net_requirement_mt'] as num?)?.toDouble() ?? 252.2,
      totalProposedAllocationMt: (json['total_proposed_allocation_mt'] as num?)?.toDouble() ?? 252.2,
      totalShortfallMt: (json['total_shortfall_mt'] as num?)?.toDouble() ?? 0.0,
      unallocatedDepotBalanceMt: (json['unallocated_depot_balance_mt'] as num?)?.toDouble() ?? 597.8,
      items: list,
    );
  }
}

class GovernanceEventItem {
  final String eventId;
  final String eventType;
  final String action;
  final String entity;
  final String actor;
  final String notes;
  final String timestamp;

  GovernanceEventItem({
    required this.eventId,
    required this.eventType,
    required this.action,
    required this.entity,
    required this.actor,
    required this.notes,
    required this.timestamp,
  });

  factory GovernanceEventItem.fromJson(Map<String, dynamic> json) {
    final ent = json['entity'] ??
        (json['entity_type'] != null
            ? '${json['entity_type']}: ${json['entity_id'] ?? ''}'
            : '');
    final act = json['actor'] ??
        (json['actor_name'] != null
            ? '${json['actor_name']} (${json['actor_role'] ?? ''})'
            : '');

    return GovernanceEventItem(
      eventId: json['event_id'] ?? '',
      eventType: json['event_type'] ?? '',
      action: json['action'] ?? '',
      entity: ent,
      actor: act,
      notes: json['notes'] ?? '',
      timestamp: json['timestamp'] ?? 'Just now',
    );
  }
}
