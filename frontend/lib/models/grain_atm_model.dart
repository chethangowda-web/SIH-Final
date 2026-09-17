class GrainAtmStockItem {
  final String commodity;
  final double capacityKg;
  final double availableStockKg;
  final double minThresholdKg;
  final bool isLowStock;

  GrainAtmStockItem({
    required this.commodity,
    required this.capacityKg,
    required this.availableStockKg,
    required this.minThresholdKg,
    required this.isLowStock,
  });

  factory GrainAtmStockItem.fromJson(Map<String, dynamic> json) {
    return GrainAtmStockItem(
      commodity: json['commodity'] ?? 'RICE',
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 500.0,
      availableStockKg: (json['available_stock_kg'] as num?)?.toDouble() ?? 0.0,
      minThresholdKg: (json['min_threshold_kg'] as num?)?.toDouble() ?? 50.0,
      isLowStock: json['is_low_stock'] ?? false,
    );
  }
}

class GrainAtmStatus {
  final String atmId;
  final String name;
  final String location;
  final String district;
  final String status;
  final bool isReady;
  final bool isLowStock;
  final List<GrainAtmStockItem> inventory;
  final String? lastReplenishedAt;

  GrainAtmStatus({
    required this.atmId,
    required this.name,
    required this.location,
    required this.district,
    required this.status,
    required this.isReady,
    required this.isLowStock,
    required this.inventory,
    this.lastReplenishedAt,
  });

  factory GrainAtmStatus.fromJson(Map<String, dynamic> json) {
    final invList = (json['inventory'] as List<dynamic>?)
            ?.map((i) => GrainAtmStockItem.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];
    return GrainAtmStatus(
      atmId: json['atm_id'] ?? 'ATM-001',
      name: json['name'] ?? 'Ration Vending Machine',
      location: json['location'] ?? 'Demo PDS Centre',
      district: json['district'] ?? 'Bengaluru Urban',
      status: json['status'] ?? 'ONLINE',
      isReady: json['is_ready'] ?? true,
      isLowStock: json['is_low_stock'] ?? false,
      inventory: invList,
      lastReplenishedAt: json['last_replenished_at'] as String?,
    );
  }
}

class BeneficiaryAtmVerification {
  final String beneficiaryId;
  final String name;
  final String cardType;
  final String cycleId;
  final double statutoryRiceKg;
  final double statutoryWheatKg;
  final double authorizedRiceKg;
  final double authorizedWheatKg;
  final bool alreadyReceived;
  final String? alreadyReceivedMessage;
  final bool stockSufficient;
  final bool eligible;
  final String? reason;
  final String atmId;

  BeneficiaryAtmVerification({
    required this.beneficiaryId,
    required this.name,
    required this.cardType,
    required this.cycleId,
    required this.statutoryRiceKg,
    required this.statutoryWheatKg,
    required this.authorizedRiceKg,
    required this.authorizedWheatKg,
    required this.alreadyReceived,
    this.alreadyReceivedMessage,
    required this.stockSufficient,
    required this.eligible,
    this.reason,
    required this.atmId,
  });

  factory BeneficiaryAtmVerification.fromJson(Map<String, dynamic> json) {
    return BeneficiaryAtmVerification(
      beneficiaryId: json['beneficiary_id'] ?? '',
      name: json['name'] ?? 'Beneficiary',
      cardType: json['card_type'] ?? 'PHH',
      cycleId: json['cycle_id'] ?? '2026-09',
      statutoryRiceKg: (json['statutory_rice_kg'] as num?)?.toDouble() ?? 20.0,
      statutoryWheatKg: (json['statutory_wheat_kg'] as num?)?.toDouble() ?? 5.0,
      authorizedRiceKg: (json['authorized_rice_kg'] as num?)?.toDouble() ?? 10.0,
      authorizedWheatKg: (json['authorized_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      alreadyReceived: json['already_received'] ?? false,
      alreadyReceivedMessage: json['already_received_message'] as String?,
      stockSufficient: json['stock_sufficient'] ?? true,
      eligible: json['eligible'] ?? true,
      reason: json['reason'] as String?,
      atmId: json['atm_id'] ?? 'ATM-001',
    );
  }
}

class GrainAtmDispenseResult {
  final bool success;
  final String transactionId;
  final String beneficiaryId;
  final String cycleId;
  final double dispensedRiceKg;
  final double dispensedWheatKg;
  final String atmId;
  final String atmLocation;
  final String receiptHash;
  final String receiptQrData;
  final String timestamp;
  final String? errorMessage;

  GrainAtmDispenseResult({
    required this.success,
    required this.transactionId,
    required this.beneficiaryId,
    required this.cycleId,
    required this.dispensedRiceKg,
    required this.dispensedWheatKg,
    required this.atmId,
    required this.atmLocation,
    required this.receiptHash,
    required this.receiptQrData,
    required this.timestamp,
    this.errorMessage,
  });

  factory GrainAtmDispenseResult.fromJson(Map<String, dynamic> json) {
    return GrainAtmDispenseResult(
      success: json['success'] ?? false,
      transactionId: json['transaction_id'] ?? '',
      beneficiaryId: json['beneficiary_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      dispensedRiceKg: (json['dispensed_rice_kg'] as num?)?.toDouble() ?? 0.0,
      dispensedWheatKg: (json['dispensed_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      atmId: json['atm_id'] ?? 'ATM-001',
      atmLocation: json['atm_location'] ?? 'Demo PDS Centre',
      receiptHash: json['receipt_hash'] ?? '',
      receiptQrData: json['receipt_qr_data'] ?? '',
      timestamp: json['timestamp'] ?? '',
      errorMessage: json['error_message'] as String?,
    );
  }
}

class AtmOperationalDetail {
  final String atmId;
  final String name;
  final String location;
  final String status;
  final double riceStockKg;
  final double wheatStockKg;
  final int todayTransactions;
  final int successfulTransactions;
  final int failedTransactions;
  final String lastReplenishment;

  AtmOperationalDetail({
    required this.atmId,
    required this.name,
    required this.location,
    required this.status,
    required this.riceStockKg,
    required this.wheatStockKg,
    required this.todayTransactions,
    required this.successfulTransactions,
    required this.failedTransactions,
    required this.lastReplenishment,
  });

  factory AtmOperationalDetail.fromJson(Map<String, dynamic> json) {
    return AtmOperationalDetail(
      atmId: json['atm_id'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      status: json['status'] ?? 'ONLINE',
      riceStockKg: (json['rice_stock_kg'] as num?)?.toDouble() ?? 0.0,
      wheatStockKg: (json['wheat_stock_kg'] as num?)?.toDouble() ?? 0.0,
      todayTransactions: json['today_transactions'] ?? 0,
      successfulTransactions: json['successful_transactions'] ?? 0,
      failedTransactions: json['failed_transactions'] ?? 0,
      lastReplenishment: json['last_replenishment'] ?? '10:30 AM',
    );
  }
}

class GrainAtmNetworkSummary {
  final int totalAtms;
  final int onlineAtms;
  final int lowStockAtms;
  final double todayDispensedRiceKg;
  final double todayDispensedWheatKg;
  final List<AtmOperationalDetail> atms;

  GrainAtmNetworkSummary({
    required this.totalAtms,
    required this.onlineAtms,
    required this.lowStockAtms,
    required this.todayDispensedRiceKg,
    required this.todayDispensedWheatKg,
    required this.atms,
  });

  factory GrainAtmNetworkSummary.fromJson(Map<String, dynamic> json) {
    final list = (json['atms'] as List<dynamic>?)
            ?.map((a) => AtmOperationalDetail.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];
    return GrainAtmNetworkSummary(
      totalAtms: json['total_atms'] ?? 5,
      onlineAtms: json['online_atms'] ?? 4,
      lowStockAtms: json['low_stock_atms'] ?? 1,
      todayDispensedRiceKg: (json['today_dispensed_rice_kg'] as num?)?.toDouble() ?? 842.0,
      todayDispensedWheatKg: (json['today_dispensed_wheat_kg'] as num?)?.toDouble() ?? 316.0,
      atms: list,
    );
  }
}
