class HealthModel {
  final String status;
  final String projectName;
  final String subtitle;
  final String version;
  final String databaseStatus;
  final String district;
  final String activeCycle;
  final int fpsCount;
  final int beneficiariesCount;
  final String serverTime;
  final String demoNotice;
  final int latencyMs;

  HealthModel({
    required this.status,
    required this.projectName,
    required this.subtitle,
    required this.version,
    required this.databaseStatus,
    required this.district,
    required this.activeCycle,
    required this.fpsCount,
    required this.beneficiariesCount,
    required this.serverTime,
    required this.demoNotice,
    required this.latencyMs,
  });

  factory HealthModel.fromJson(Map<String, dynamic> json, int latencyMs) {
    return HealthModel(
      status: json['status'] ?? 'unknown',
      projectName: json['project_name'] ?? 'PDS DemandSync',
      subtitle: json['subtitle'] ?? '',
      version: json['version'] ?? '1.0.0',
      databaseStatus: json['database_status'] ?? 'unknown',
      district: json['district'] ?? 'Bengaluru Urban PDS Pilot',
      activeCycle: json['active_cycle'] ?? json['current_cycle'] ?? '2026-09',
      fpsCount: json['fps_count'] ?? 20,
      beneficiariesCount: json['beneficiaries_count'] ?? 2000,
      serverTime: json['server_time'] ?? '',
      demoNotice: json['demo_notice'] ?? 'DEMO DATA — NOT GOVERNMENT DATA',
      latencyMs: latencyMs,
    );
  }
}
