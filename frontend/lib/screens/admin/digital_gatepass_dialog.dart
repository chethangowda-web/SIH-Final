import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';
import 'readiness_alerts_dialog.dart';

class DigitalGatepassDialog extends StatefulWidget {
  final String cycleId;
  final String? initialTruckId;

  const DigitalGatepassDialog({
    super.key,
    this.cycleId = '2026-09',
    this.initialTruckId,
  });

  @override
  State<DigitalGatepassDialog> createState() => _DigitalGatepassDialogState();
}

class _DigitalGatepassDialogState extends State<DigitalGatepassDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isAdvancing = false;
  String? _errorMessage;
  List<DigitalGatepass> _gatepasses = [];
  int _selectedIdx = 0;

  @override
  void initState() {
    super.initState();
    _loadGatepasses();
  }

  Future<void> _loadGatepasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.fetchAllGatepasses(cycleId: widget.cycleId);
      if (mounted) {
        setState(() {
          _gatepasses = res;
          _isLoading = false;
          if (widget.initialTruckId != null) {
            final idx = _gatepasses
                .indexWhere((g) => g.truckId == widget.initialTruckId);
            if (idx >= 0) _selectedIdx = idx;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _advanceStage(String targetStatus) async {
    final gp = _gatepasses[_selectedIdx];
    setState(() => _isAdvancing = true);

    try {
      final updated =
          await _apiService.advanceGatepassStage(gp.gatepassId, targetStatus);
      if (mounted) {
        setState(() {
          _gatepasses[_selectedIdx] = updated;
          _isAdvancing = false;
        });

        if (targetStatus == 'DISPATCH_CONFIRMED') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Dispatch Confirmed! Vehicle in transit & Multi-channel Readiness Alerts (WhatsApp, SMS, IVR) automatically dispatched!'),
                  ),
                ],
              ),
              backgroundColor: AppConstants.successGreen,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'View Alerts',
                textColor: Colors.white,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ReadinessAlertsDialog(cycleId: widget.cycleId),
                  );
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gatepass advanced to ${targetStatus.replaceAll('_', ' ')}'),
              backgroundColor: AppConstants.primaryNavy,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdvancing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to advance stage: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: 1150,
        height: 860,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConstants.primaryNavy),
                      SizedBox(height: 12),
                      Text('Generating Digital Pre-Dispatch Gatepasses & Linking Manifests...',
                          style: TextStyle(
                              color: AppConstants.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppConstants.dangerRed, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style: const TextStyle(
                              color: AppConstants.dangerRed,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadGatepasses,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              )
            else ...[
              _buildTruckSelector(),
              const SizedBox(height: 12),
              Expanded(child: _buildGatepassDocument()),
            ],
            const SizedBox(height: 12),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.purpleAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.badge_rounded,
                  color: AppConstants.purpleAccent, size: 24),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Physical-Dispatch Bridge: Digital Gatepass & Readiness Handshake',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Badge(
                      label: Text('SIMULATED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: AppConstants.accentAmber,
                    ),
                  ],
                ),
                Text(
                  'Locked Manifest → Digital Gatepass → Warehouse Approval → Vehicle Loading → Dispatch Confirmed',
                  style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildTruckSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_gatepasses.length, (idx) {
            final gp = _gatepasses[idx];
            final isSelected = idx == _selectedIdx;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _selectedIdx = idx),
                icon: Icon(Icons.local_shipping_rounded,
                    size: 14,
                    color: isSelected ? Colors.white : AppConstants.primaryNavy),
                label: Text(
                  '${gp.truckId} (${gp.corridor.replaceAll('_', ' ')})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? AppConstants.primaryNavy
                      : Colors.grey.shade200,
                  foregroundColor:
                      isSelected ? Colors.white : AppConstants.textPrimary,
                  elevation: isSelected ? 2 : 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGatepassDocument() {
    if (_gatepasses.isEmpty) {
      return const Center(child: Text('No gatepasses available.'));
    }
    final gp = _gatepasses[_selectedIdx];

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConstants.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Disclaimer Alert
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppConstants.accentAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppConstants.accentAmber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppConstants.accentAmber, size: 14),
                  SizedBox(width: 8),
                  Text(
                    'PROTOTYPE / SIMULATED DIGITAL GATEPASS — NOT AN OFFICIAL GOVERNMENT DOCUMENT',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.accentAmber),
                  ),
                ],
              ),
            ),

            // Header Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_rounded,
                            size: 18, color: AppConstants.primaryNavy),
                        const SizedBox(width: 6),
                        Text(
                          'FOOD & CIVIL SUPPLIES DEPARTMENT • KARNATAKA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppConstants.primaryNavy.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pre-Dispatch Digital Gatepass: ${gp.gatepassId}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppConstants.primaryNavy),
                    ),
                  ],
                ),
                _buildStatusBadge(gp.status),
              ],
            ),
            const Divider(height: 20),

            // Key Attributes Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildInfoRow('Linked Manifest ID', gp.manifestId),
                      _buildInfoRow('Dispatch Corridor', gp.corridor.replaceAll('_', ' ')),
                      _buildInfoRow('Source Godown', '${gp.depotName} (${gp.depotLocation})'),
                      _buildInfoRow('Assigned Bay & Window', '${gp.loadingBay} • ${gp.loadingWindow}'),
                      _buildInfoRow('Fleet Carrier', '${gp.truckModel} (${gp.truckId})'),
                      _buildInfoRow('Authorized Driver', '${gp.driverName} (${gp.driverPhone})'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildWeighbridgeCard(gp),
                      const SizedBox(height: 10),
                      _buildQrCard(gp),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // 4-Stage Physical Bridge Timeline
            const Text(
              '4-Stage Physical Handshake Lifecycle',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryNavy),
            ),
            const SizedBox(height: 10),
            _buildTimelineView(gp),

            const Divider(height: 20),

            // Itemized Drops Table
            const Text(
              'Itemized Delivery Drops & Dealer Allocations',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryNavy),
            ),
            const SizedBox(height: 8),
            _buildDropsTable(gp),

            const SizedBox(height: 16),
            _buildStageActionControls(gp),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppConstants.accentBlue;
    if (status == 'DISPATCH_CONFIRMED') color = AppConstants.successGreen;
    if (status == 'VEHICLE_LOADED') color = AppConstants.purpleAccent;
    if (status == 'WAREHOUSE_APPROVED' || status == 'WAREHOUSE_VERIFIED') {
      color = const Color(0xFF0284C7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppConstants.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeighbridgeCard(DigitalGatepass gp) {
    final slip = gp.weighbridgeSlip;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.scale_outlined,
                  color: AppConstants.accentBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                'Weighbridge Certification (${slip?.slipNumber ?? 'WB-01'})',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          const Divider(height: 10),
          _buildMiniWeightRow(
              'Tare Weight (Empty)', '${slip?.tareWeightKg.toStringAsFixed(0)} kg'),
          _buildMiniWeightRow(
              'Net Foodgrain Payload', '${gp.totalPayloadKg.toStringAsFixed(0)} kg'),
          _buildMiniWeightRow(
              'Gross Dispatch Weight', '${slip?.grossWeightKg.toStringAsFixed(0)} kg'),
        ],
      ),
    );
  }

  Widget _buildMiniWeightRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppConstants.textSecondary)),
          Text(val,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildQrCard(DigitalGatepass gp) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: const Icon(Icons.qr_code_2_rounded, size: 36, color: AppConstants.primaryNavy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SECURITY DIGITAL TOKEN',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textSecondary)),
                Text(gp.securityToken,
                    style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy)),
                const SizedBox(height: 2),
                const Text('Scan for ePoS Gate Clearance',
                    style: TextStyle(fontSize: 9, color: AppConstants.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(DigitalGatepass gp) {
    return Row(
      children: gp.eventTimeline.map((item) {
        final isDone = item.status == 'COMPLETED';
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDone
                  ? AppConstants.successGreen.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDone
                    ? AppConstants.successGreen.withValues(alpha: 0.3)
                    : AppConstants.cardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 14,
                      color: isDone ? AppConstants.successGreen : Colors.grey,
                    ),
                    Text(
                      item.timestamp.split(' ').last,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDone
                        ? AppConstants.primaryNavy
                        : AppConstants.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.actorName.isNotEmpty ? item.actorName : item.officer,
                  style: const TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: AppConstants.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.referenceId.isNotEmpty)
                  Text(
                    'Ref: ${item.referenceId}',
                    style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 8,
                        color: AppConstants.textTertiary),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropsTable(DigitalGatepass gp) {
    return Table(
      border: TableBorder.all(color: AppConstants.cardBorder, borderRadius: BorderRadius.circular(6)),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            Padding(
                padding: EdgeInsets.all(6),
                child: Text('#',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            Padding(
                padding: EdgeInsets.all(6),
                child: Text('Fair Price Shop (FPS)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            Padding(
                padding: EdgeInsets.all(6),
                child: Text('Rice Drop',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            Padding(
                padding: EdgeInsets.all(6),
                child: Text('Wheat Drop',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            Padding(
                padding: EdgeInsets.all(6),
                child: Text('Total Payload',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          ],
        ),
        ...gp.deliveryStops.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final stop = entry.value;
          return TableRow(
            children: [
              Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('$idx', style: const TextStyle(fontSize: 10))),
              Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('${stop.fpsName} (${stop.fpsId})',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600))),
              Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('${stop.riceKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 10))),
              Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('${stop.wheatKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 10))),
              Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('${stop.totalKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.successGreen))),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStageActionControls(DigitalGatepass gp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.touch_app_outlined,
                  color: AppConstants.accentBlue, size: 16),
              SizedBox(width: 6),
              Text(
                'Advance Physical Handshake Stage:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: _isAdvancing
                    ? null
                    : () => _advanceStage('WAREHOUSE_APPROVED'),
                child: const Text('1. Warehouse Approval',
                    style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed:
                    _isAdvancing ? null : () => _advanceStage('VEHICLE_LOADED'),
                child: const Text('2. Vehicle Loading',
                    style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isAdvancing
                    ? null
                    : () => _advanceStage('DISPATCH_CONFIRMED'),
                icon: const Icon(Icons.departure_board_rounded, size: 14),
                label: const Text('3. Confirm Dispatch & Send Alerts',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.successGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Notice: PROTOTYPE / SIMULATED DIGITAL GATEPASS — NOT AN OFFICIAL GOVERNMENT DOCUMENT',
          style: TextStyle(fontSize: 10, color: AppConstants.textTertiary),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
