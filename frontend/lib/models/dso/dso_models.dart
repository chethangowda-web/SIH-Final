// DSO Models — Extended for Workflow-First Command Center
// Source of truth: pds_demandsync.db via /admin/dso/* API endpoints

enum DsoWorkflowState {
  planningOpen,
  demandValidated,
  allocated,
  optimized,
  dispatchAuthorized,
  deliveryVerification,
  evaluated,
  cycleClosed,
  unknown;

  static DsoWorkflowState fromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'PLANNING_OPEN':
        return DsoWorkflowState.planningOpen;
      case 'DEMAND_VALIDATED':
        return DsoWorkflowState.demandValidated;
      case 'ALLOCATED':
        return DsoWorkflowState.allocated;
      case 'OPTIMIZED':
        return DsoWorkflowState.optimized;
      case 'DISPATCH_AUTHORIZED':
        return DsoWorkflowState.dispatchAuthorized;
      case 'DELIVERY_VERIFICATION':
        return DsoWorkflowState.deliveryVerification;
      case 'EVALUATED':
        return DsoWorkflowState.evaluated;
      case 'CYCLE_CLOSED':
        return DsoWorkflowState.cycleClosed;
      default:
        return DsoWorkflowState.unknown;
    }
  }

  int get stageNumber {
    switch (this) {
      case DsoWorkflowState.planningOpen:
        return 1;
      case DsoWorkflowState.demandValidated:
        return 2;
      case DsoWorkflowState.allocated:
        return 3;
      case DsoWorkflowState.optimized:
        return 4;
      case DsoWorkflowState.dispatchAuthorized:
        return 5;
      case DsoWorkflowState.deliveryVerification:
        return 6;
      case DsoWorkflowState.evaluated:
      case DsoWorkflowState.cycleClosed:
        return 7;
      default:
        return 1;
    }
  }

  String get displayLabel {
    switch (this) {
      case DsoWorkflowState.planningOpen:
        return 'Plan & Forecast';
      case DsoWorkflowState.demandValidated:
        return 'Validate Demand';
      case DsoWorkflowState.allocated:
        return 'Approve Allocation';
      case DsoWorkflowState.optimized:
        return 'Optimize Supply';
      case DsoWorkflowState.dispatchAuthorized:
        return 'Authorize Dispatch';
      case DsoWorkflowState.deliveryVerification:
        return 'Verify Delivery';
      case DsoWorkflowState.evaluated:
        return 'Evaluate & Close';
      case DsoWorkflowState.cycleClosed:
        return 'Cycle Closed';
      default:
        return 'Loading...';
    }
  }

  String get currentActionMessage {
    switch (this) {
      case DsoWorkflowState.planningOpen:
        return 'Citizen intent signals are being collected. Review forecast vs baseline demand and validate when ready.';
      case DsoWorkflowState.demandValidated:
        return 'Demand snapshot validated and sealed. Review stock allocation plan before approving.';
      case DsoWorkflowState.allocated:
        return 'Stock allocation approved. Review supply route optimization plan before authorizing.';
      case DsoWorkflowState.optimized:
        return 'Route optimization approved. Review dispatch manifests and authorize truck movements.';
      case DsoWorkflowState.dispatchAuthorized:
        return 'Dispatch authorized. Monitor truck movements and verify deliveries at FPS locations.';
      case DsoWorkflowState.deliveryVerification:
        return 'Delivery verification in progress. Review FPS receipts and reconciliation data.';
      case DsoWorkflowState.evaluated:
        return 'Cycle evaluation complete. Review reconciliation summary and close the cycle when satisfied.';
      case DsoWorkflowState.cycleClosed:
        return 'Planning cycle officially closed and archived. All records sealed.';
      default:
        return 'Loading workflow state from backend...';
    }
  }

  String get primaryActionLabel {
    switch (this) {
      case DsoWorkflowState.planningOpen:
        return 'Validate Demand';
      case DsoWorkflowState.demandValidated:
        return 'Approve Allocation';
      case DsoWorkflowState.allocated:
        return 'Approve Optimization';
      case DsoWorkflowState.optimized:
        return 'Authorize Dispatch';
      case DsoWorkflowState.dispatchAuthorized:
        return 'Review Deliveries';
      case DsoWorkflowState.deliveryVerification:
        return 'Review Reconciliation';
      case DsoWorkflowState.evaluated:
        return 'Close Cycle';
      case DsoWorkflowState.cycleClosed:
        return 'View Archive';
      default:
        return 'Loading...';
    }
  }
}

enum DsoStageStatus {
  completed,
  current,
  pending,
  blocked,
  notStarted;

  String get label {
    switch (this) {
      case DsoStageStatus.completed:
        return 'COMPLETED';
      case DsoStageStatus.current:
        return 'IN PROGRESS';
      case DsoStageStatus.pending:
        return 'PENDING';
      case DsoStageStatus.blocked:
        return 'BLOCKED';
      case DsoStageStatus.notStarted:
        return 'NOT STARTED';
    }
  }
}

class DsoStageInfo {
  final int number;
  final String title;
  final String description;
  final DsoStageStatus status;

  const DsoStageInfo({
    required this.number,
    required this.title,
    required this.description,
    required this.status,
  });
}

class DsoSupplyChainNode {
  final String id;
  final String label;
  final String? value;
  final String status;
  final String? subLabel;

  const DsoSupplyChainNode({
    required this.id,
    required this.label,
    this.value,
    required this.status,
    this.subLabel,
  });
}

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
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      fps: (json['fps'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      detectedAt: (json['detected_at'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
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
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      why: (json['why'] ?? '').toString(),
      evidence: (json['evidence'] ?? '').toString(),
    );
  }
}

class DsoCommandOverview {
  final String status;
  final String district;
  final String cycleId;
  final String currentStage;
  final DsoWorkflowState workflowState;
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
    required this.workflowState,
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

    final stageStr = json['current_stage'] as String? ?? 'PLANNING_OPEN';

    return DsoCommandOverview(
      status: (json['status'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      cycleId: (json['cycle_id'] ?? '').toString(),
      currentStage: stageStr,
      workflowState: DsoWorkflowState.fromString(stageStr),
      metrics: metricsMap,
      demandBreakdown: json['demand_breakdown'] as Map<String, dynamic>? ?? {},
      exceptions: excList,
      aiInsights: aiList,
      aiRecommendation: json['ai_recommendation'] as Map<String, dynamic>? ?? {},
      dataLastUpdated: json['data_last_updated'] ?? '',
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
      cycleId: (json['cycle_id'] ?? '').toString(),
      availableDepotStockMt: (json['available_depot_stock_mt'] as num?)?.toDouble() ?? 0.0,
      totalValidatedDemandMt: (json['total_validated_demand_mt'] as num?)?.toDouble() ?? 0.0,
      totalExistingFpsStockMt: (json['total_existing_fps_stock_mt'] as num?)?.toDouble() ?? 0.0,
      totalNetRequirementMt: (json['total_net_requirement_mt'] as num?)?.toDouble() ?? 0.0,
      totalProposedAllocationMt: (json['total_proposed_allocation_mt'] as num?)?.toDouble() ?? 0.0,
      totalShortfallMt: (json['total_shortfall_mt'] as num?)?.toDouble() ?? 0.0,
      unallocatedDepotBalanceMt: (json['unallocated_depot_balance_mt'] as num?)?.toDouble() ?? 0.0,
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
      eventId: (json['event_id'] ?? '').toString(),
      eventType: (json['event_type'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      entity: ent.toString(),
      actor: act.toString(),
      notes: (json['notes'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
    );
  }
}
