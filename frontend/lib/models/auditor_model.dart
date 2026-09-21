import 'dart:convert';

/// Auditor Record & Workflow State Data Models
class AuditRecordModel {
  final String auditId;
  final String cycleId;
  final String fpsId;
  final String fpsName;
  final String district;
  final String auditorId;
  final String auditType;
  final String scheduledDate;
  final int currentStage;
  final String status;
  final String riskLevel;
  final String riskReason;
  final String assignedTeam;
  final bool recordsVerified;
  final String? inspectionId;
  final double reconciliationVarianceKg;
  final int findingsCount;
  final String? reportId;
  final String? reportHash;
  final String? closedAt;
  final String? closedBy;
  final String? closureReason;
  final List<AuditFindingModel> findings;
  final List<Map<String, dynamic>> timeline;

  AuditRecordModel({
    required this.auditId,
    required this.cycleId,
    required this.fpsId,
    required this.fpsName,
    required this.district,
    required this.auditorId,
    required this.auditType,
    required this.scheduledDate,
    required this.currentStage,
    required this.status,
    required this.riskLevel,
    required this.riskReason,
    required this.assignedTeam,
    required this.recordsVerified,
    this.inspectionId,
    required this.reconciliationVarianceKg,
    required this.findingsCount,
    this.reportId,
    this.reportHash,
    this.closedAt,
    this.closedBy,
    this.closureReason,
    this.findings = const [],
    this.timeline = const [],
  });

  factory AuditRecordModel.fromJson(Map<String, dynamic> json) {
    return AuditRecordModel(
      auditId: json['audit_id']?.toString() ?? '',
      cycleId: json['cycle_id']?.toString() ?? '2026-09',
      fpsId: json['fps_id']?.toString() ?? '',
      fpsName: json['fps_name']?.toString() ?? json['fps_id']?.toString() ?? 'Fair Price Shop',
      district: json['district']?.toString() ?? 'Bengaluru Urban',
      auditorId: json['auditor_id']?.toString() ?? 'auditor_user',
      auditType: json['audit_type']?.toString() ?? 'FULL_AUDIT',
      scheduledDate: json['scheduled_date']?.toString() ?? '',
      currentStage: json['current_stage'] is int ? json['current_stage'] as int : int.tryParse(json['current_stage']?.toString() ?? '1') ?? 1,
      status: json['status']?.toString() ?? 'SCHEDULED',
      riskLevel: json['risk_level']?.toString() ?? 'NORMAL',
      riskReason: json['risk_reason']?.toString() ?? 'Routine Scheduled Audit',
      assignedTeam: json['assigned_team']?.toString() ?? 'Vigilance Team Alpha',
      recordsVerified: json['records_verified'] == 1 || json['records_verified'] == true,
      inspectionId: json['inspection_id']?.toString(),
      reconciliationVarianceKg: (json['reconciliation_variance_kg'] as num?)?.toDouble() ?? 0.0,
      findingsCount: json['findings_count'] is int ? json['findings_count'] as int : 0,
      reportId: json['report_id']?.toString(),
      reportHash: json['report_hash']?.toString(),
      closedAt: json['closed_at']?.toString(),
      closedBy: json['closed_by']?.toString(),
      closureReason: json['closure_reason']?.toString(),
      findings: (json['findings'] as List<dynamic>?)
              ?.map((f) => AuditFindingModel.fromJson(Map<String, dynamic>.from(f as Map)))
              .toList() ??
          [],
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((t) => Map<String, dynamic>.from(t as Map))
              .toList() ??
          [],
    );
  }

  String get stageName {
    switch (currentStage) {
      case 1:
        return '01 PLAN & SCHEDULE';
      case 2:
        return '02 VERIFY RECORDS';
      case 3:
        return '03 INSPECT FPS';
      case 4:
        return '04 ANALYZE COMPLIANCE';
      case 5:
        return '05 GENERATE REPORT';
      case 6:
        return '06 CLOSE AUDIT';
      default:
        return 'STAGE $currentStage';
    }
  }
}

class AuditFindingModel {
  final int? id;
  final String auditId;
  final String findingType;
  final String severity;
  final String title;
  final String description;
  final List<String> evidenceRefs;
  final String? auditorRecommendation;
  final String createdBy;
  final String createdAt;

  AuditFindingModel({
    this.id,
    required this.auditId,
    required this.findingType,
    required this.severity,
    required this.title,
    required this.description,
    this.evidenceRefs = const [],
    this.auditorRecommendation,
    required this.createdBy,
    required this.createdAt,
  });

  factory AuditFindingModel.fromJson(Map<String, dynamic> json) {
    List<String> refs = [];
    if (json['evidence_refs'] != null) {
      try {
        if (json['evidence_refs'] is List) {
          refs = (json['evidence_refs'] as List).map((e) => e.toString()).toList();
        } else {
          final parsed = jsonDecode(json['evidence_refs'].toString());
          if (parsed is List) refs = parsed.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return AuditFindingModel(
      id: json['id'] is int ? json['id'] as int : null,
      auditId: json['audit_id']?.toString() ?? '',
      findingType: json['finding_type']?.toString() ?? 'COMPLIANCE_NOTE',
      severity: json['severity']?.toString() ?? 'MEDIUM',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      evidenceRefs: refs,
      auditorRecommendation: json['auditor_recommendation']?.toString(),
      createdBy: json['created_by']?.toString() ?? 'auditor_user',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class AuditOverviewModel {
  final String cycleId;
  final String auditorId;
  final String role;
  final int totalAudits;
  final int activeAudits;
  final int closedAudits;
  final int criticalRisks;
  final Map<String, int> stageBreakdown;
  final List<Map<String, dynamic>> recentActivity;

  AuditOverviewModel({
    required this.cycleId,
    required this.auditorId,
    required this.role,
    required this.totalAudits,
    required this.activeAudits,
    required this.closedAudits,
    required this.criticalRisks,
    required this.stageBreakdown,
    required this.recentActivity,
  });

  factory AuditOverviewModel.fromJson(Map<String, dynamic> json) {
    final sum = json['summary'] as Map<String, dynamic>? ?? {};
    final sb = json['stage_breakdown'] as Map<String, dynamic>? ?? {};

    return AuditOverviewModel(
      cycleId: json['cycle_id']?.toString() ?? '2026-09',
      auditorId: json['auditor_id']?.toString() ?? 'auditor_user',
      role: json['role']?.toString() ?? 'AUDITOR',
      totalAudits: (sum['total_audits'] as num?)?.toInt() ?? 0,
      activeAudits: (sum['active_audits'] as num?)?.toInt() ?? 0,
      closedAudits: (sum['closed_audits'] as num?)?.toInt() ?? 0,
      criticalRisks: (sum['critical_risks'] as num?)?.toInt() ?? 0,
      stageBreakdown: sb.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      recentActivity: (json['recent_activity'] as List<dynamic>?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          [],
    );
  }
}
