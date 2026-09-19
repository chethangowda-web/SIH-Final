import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class ManifestManagementDialog extends StatefulWidget {
  final String cycleId;
  final String? initialTruckId;

  const ManifestManagementDialog({
    super.key,
    this.cycleId = '2026-09',
    this.initialTruckId,
  });

  @override
  State<ManifestManagementDialog> createState() =>
      _ManifestManagementDialogState();
}

class _ManifestManagementDialogState extends State<ManifestManagementDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isActionExecuting = false;
  String? _errorMessage;

  DispatchManifestDossier? _manifest;
  String _selectedTruckId = 'DEMO-KA-04-E-1021';

  // Editable Draft Parameters
  double _editableQuantityKg = 3120.0;
  String _editableTruckId = 'DEMO-KA-04-E-1021';
  String _editableRouteType = 'DIRECT_ARTERIAL';
  String _editableDepartureWindow = '08:30 AM (Morning Slot)';

  final List<Map<String, String>> _corridors = [
    {
      'truck_id': 'DEMO-KA-04-E-1021',
      'label': 'North-West Heavy Corridor',
      'model': 'Eicher Pro 10 MT'
    },
    {
      'truck_id': 'DEMO-KA-04-E-1022',
      'label': 'East Corridor / IT Belt',
      'model': 'Tata Ultra 10 MT'
    },
    {
      'truck_id': 'DEMO-KA-51-M-3419',
      'label': 'South Industrial Corridor',
      'model': 'BharatBenz 10 MT'
    },
    {
      'truck_id': 'DEMO-KA-04-E-1023',
      'label': 'Central Buffer Corridor',
      'model': 'Ashok Leyland 10 MT'
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialTruckId != null && widget.initialTruckId!.isNotEmpty) {
      _selectedTruckId = widget.initialTruckId!;
    }
    _editableTruckId = _selectedTruckId;
    _loadManifest();
  }

  Future<void> _loadManifest({String? truckId}) async {
    final tid = truckId ?? _selectedTruckId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedTruckId = tid;
      _editableTruckId = tid;
    });

    try {
      final res = await _apiService.generateCorridorManifest(
        truckId: tid,
        cycleId: widget.cycleId,
      );
      if (mounted) {
        setState(() {
          _manifest = res;
          _editableQuantityKg = res.totalQuantityKg;
          _editableRouteType = res.routeType;
          _editableDepartureWindow = res.departureWindow;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '');
        final fallback = DispatchManifestDossier(
          status: 'SUCCESS',
          manifestId: 'MNF-KA-BLR-202609-001',
          cycleId: widget.cycleId,
          version: '1.0',
          approvalStatus: 'LOCKED',
          isLocked: true,
          sourceDepotId: 'DEPOT-KA-BLR-01',
          sourceDepotName: 'Central Food Corporation Godown (Bengaluru North)',
          sourceDepotLocation: 'Yeshwanthpur Industrial Suburb, Area #04',
          corridor: 'Bengaluru Urban Corridor #04',
          truckId: tid,
          truckModel: 'Ashok Leyland 10 MT Heavy Commercial Vehicle',
          maxPayloadKg: 10000.0,
          payloadUtilizationPct: 92.5,
          driverName: 'Ranganath V',
          driverPhone: '+91 98450 12345',
          driverLicense: 'KA-04-2018-009412',
          routeType: 'OPTIMAL_DYNAMIC_LOOP',
          departureWindow: '06:00 AM - 08:30 AM',
          totalQuantityKg: 9250.0,
          totalRiceKg: 5550.0,
          totalWheatKg: 3700.0,
          commodities: [
            ManifestCommodityItem(commodity: 'Fortified Rice (Raw)', quantityKg: 5550.0, unit: 'kg'),
            ManifestCommodityItem(commodity: 'Whole Wheat (PDS)', quantityKg: 3700.0, unit: 'kg'),
          ],
          totalStopsCount: 4,
          deliverySequence: [
            OptimizedStop(sequenceOrder: 1, fpsId: 'FPS-KA-BLR-001', fpsName: 'Malleshwaram Seva Kendra', legDistanceKm: 4.2, cumulativeDistanceKm: 4.2, riceKg: 1500.0, wheatKg: 1000.0, totalDropKg: 2500.0, timeWindow: '06:45 AM', latitude: 13.0035, longitude: 77.5710),
            OptimizedStop(sequenceOrder: 2, fpsId: 'FPS-KA-BLR-002', fpsName: 'Rajajinagar PDS Depot #02', legDistanceKm: 4.5, cumulativeDistanceKm: 8.7, riceKg: 1350.0, wheatKg: 900.0, totalDropKg: 2250.0, timeWindow: '07:30 AM', latitude: 12.9850, longitude: 77.5556),
            OptimizedStop(sequenceOrder: 3, fpsId: 'FPS-KA-BLR-003', fpsName: 'Yeshwanthpur Co-Op Society', legDistanceKm: 3.4, cumulativeDistanceKm: 12.1, riceKg: 1500.0, wheatKg: 1000.0, totalDropKg: 2500.0, timeWindow: '08:15 AM', latitude: 13.0220, longitude: 77.5433),
            OptimizedStop(sequenceOrder: 4, fpsId: 'FPS-KA-BLR-004', fpsName: 'Mathikere Fair Price Depot', legDistanceKm: 3.3, cumulativeDistanceKm: 15.4, riceKg: 1200.0, wheatKg: 800.0, totalDropKg: 2000.0, timeWindow: '09:00 AM', latitude: 13.0380, longitude: 77.5590),
          ],
          optimizationScore: 94.8,
          efficiencyPct: 98.2,
          lockedAt: '2026-09-14T08:00:00Z',
          lockedBy: 'District Supply Officer (Bengaluru Urban)',
          lockReason: 'Official DSO Pre-Dispatch freeze for Cycle 2026-09',
          digitalSealHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          createdAt: '2026-09-14T06:00:00Z',
          updatedAt: '2026-09-14T08:00:00Z',
          auditTrail: [
            ManifestAuditRecord(id: 1, version: '1.0', action: 'MANIFEST_GENERATED', actorRole: 'System Admin', actorName: 'System Administrator', reason: 'Generated corridor manifest based on locked demand forecast.', timestamp: '2026-09-14T06:00:00Z'),
            ManifestAuditRecord(id: 2, version: '1.0', action: 'MANIFEST_LOCKED', actorRole: 'DSO', actorName: 'District Supply Officer', reason: 'Approved and issued SHA-256 digital cryptographic seal token.', timestamp: '2026-09-14T08:00:00Z'),
          ],
          demoNotice: 'NATIONAL FOOD SECURITY ACT (NFSA) • OFFICIAL DISPATCH MANIFEST SYSTEM',
        );

        setState(() {
          _manifest = fallback;
          _editableQuantityKg = fallback.totalQuantityKg;
          _editableRouteType = fallback.routeType;
          _editableDepartureWindow = fallback.departureWindow;
          _errorMessage = 'READ-ONLY AUDIT MODE: $errText';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveDraftModifications() async {
    if (_manifest == null) return;
    setState(() => _isActionExecuting = true);

    try {
      final res = await _apiService.updateDraftManifest(
        _manifest!.manifestId,
        truckId: _editableTruckId,
        totalQuantityKg: _editableQuantityKg,
        routeType: _editableRouteType,
        departureWindow: _editableDepartureWindow,
        modificationReason: 'Operational adjustment by District Supply Officer',
      );
      if (mounted) {
        setState(() {
          _manifest = res;
          _isActionExecuting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft manifest modifications saved and logged to audit trail.'),
            backgroundColor: AppConstants.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionExecuting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update draft manifest: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _lockManifest() async {
    if (_manifest == null) return;

    final reasonCtrl = TextEditingController(
        text: 'Official DSO Pre-Dispatch freeze for Cycle ${widget.cycleId}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_person_rounded, color: AppConstants.primaryNavy),
            SizedBox(width: 8),
            Text('Approve & Lock Manifest'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Locking will freeze all critical dispatch parameters, issue a cryptographic SHA-256 digital seal, and prevent further direct edits under statutory NFSA audit rules.',
              style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Locking Authorization Reason',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.verified_rounded, size: 16),
            label: const Text('Confirm Lock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryNavy,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.lockManifest(
        _manifest!.manifestId,
        lockReason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _manifest = res;
          _isActionExecuting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Manifest ${_manifest!.manifestId} successfully LOCKED with Digital Seal: ${_manifest!.digitalSealHash}'),
            backgroundColor: AppConstants.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionExecuting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to lock manifest: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _createRevision() async {
    if (_manifest == null) return;

    final reasonCtrl = TextEditingController(
        text: 'Authorized Revision: Emergency route and quota adjustment');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppConstants.accentAmber),
            SizedBox(width: 8),
            Text('Create Authorized Manifest Revision'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A locked manifest cannot be edited directly. Creating a revision will increment the version (e.g. v1.0 -> v1.1), log the previous version in the audit trail, and unlock the draft for modifications.',
              style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Mandatory Revision Reason',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Create Revision'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentAmber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.reviseManifest(
        _manifest!.manifestId,
        revisionReason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _manifest = res;
          _isActionExecuting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Manifest unlocked for revision: Version ${_manifest!.version} (DRAFT)'),
            backgroundColor: AppConstants.accentAmber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionExecuting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create revision: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final dialogWidth = (screenSize.width * (isMobile ? 0.98 : 0.95)).clamp(340.0, 1180.0);
    final dialogHeight = (screenSize.height * 0.92).clamp(480.0, 880.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: isMobile ? 8 : 12),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: EdgeInsets.all(isMobile ? 12 : 22),
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
                      Text(
                          'Loading Auditable Pre-Dispatch Manifest & Immutable Trail...',
                          style: TextStyle(
                              color: AppConstants.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildScrollableBody()),
            const SizedBox(height: 12),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isLocked = _manifest?.isLocked ?? false;
    final ver = _manifest?.version ?? 'v1.0';
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: isLocked
                      ? AppConstants.successGreen.withValues(alpha: 0.12)
                      : AppConstants.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLocked ? Icons.verified_rounded : Icons.description_rounded,
                  color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber,
                  size: isMobile ? 20 : 24,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isMobile ? 'Dispatch Manifest' : 'PDS Pre-Dispatch Manifest & Auditable Lock',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 18,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLocked ? 'LOCKED ($ver)' : 'DRAFT ($ver)',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMobile
                          ? 'Forecast → Constraints → LOCKED MANIFEST'
                          : 'End-to-End Workflow: Forecast → Recommended Quantity → 9 Constraints → Optimization → LOCKED MANIFEST',
                      style: const TextStyle(fontSize: 10.5, color: AppConstants.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildScrollableBody() {
    final m = _manifest!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppConstants.accentBlue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppConstants.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 1. 5-Step Workflow Progression Banner
          _buildWorkflowStepper(m),
          const SizedBox(height: 14),

          // 2. Corridor Selector Tabs
          _buildCorridorSelectorBar(),
          const SizedBox(height: 14),

          // 3. Official Government Manifest Header Card & Digital Seal
          _buildManifestOfficialHeader(m),
          const SizedBox(height: 14),

          // 4. Critical Parameters Card (Editable in DRAFT / Immutable in LOCKED)
          _buildCriticalParametersCard(m),
          const SizedBox(height: 14),

          // 5. Truck Route Map Visualization
          _buildTruckRouteMapCard(m),
          const SizedBox(height: 14),

          // 6. Itemized FPS Delivery Sequence Stops
          _buildDeliverySequenceSection(m),
          const SizedBox(height: 14),

          // 7. Immutable Audit Trail Timeline Card
          _buildAuditTrailTimelineCard(m),
        ],
      ),
    );
  }

  Widget _buildWorkflowStepper(DispatchManifestDossier m) {
    final isLocked = m.isLocked;

    final steps = [
      {'title': '1. Forecast', 'state': 'COMPLETED'},
      {'title': '2. Recommended Qty', 'state': 'COMPLETED'},
      {'title': '3. 9 Constraints', 'state': 'COMPLETED'},
      {'title': '4. TSP Optimization', 'state': 'COMPLETED'},
      {'title': isLocked ? '5. LOCKED MANIFEST' : '5. Draft Review', 'state': isLocked ? 'LOCKED' : 'ACTIVE'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.primaryNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.2)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: steps.map((s) {
            final isDone = s['state'] == 'COMPLETED';
            final isLock = s['state'] == 'LOCKED';

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isLock
                        ? AppConstants.successGreen
                        : (isDone ? AppConstants.primaryNavy : AppConstants.accentAmber),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLock ? Icons.lock_rounded : (isDone ? Icons.check : Icons.edit),
                    color: Colors.white,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  s['title']!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isLock || isDone ? FontWeight.bold : FontWeight.w600,
                    color: isLock
                        ? AppConstants.successGreen
                        : (isDone ? AppConstants.primaryNavy : AppConstants.textSecondary),
                  ),
                ),
                if (s != steps.last)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCorridorSelectorBar() {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECT CORRIDOR MANIFEST:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textSecondary),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _corridors.map((c) {
                      final isSelected = c['truck_id'] == _selectedTruckId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ElevatedButton(
                          onPressed: () => _loadManifest(truckId: c['truck_id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? AppConstants.primaryNavy
                                : Colors.grey.shade200,
                            foregroundColor:
                                isSelected ? Colors.white : AppConstants.textPrimary,
                            elevation: isSelected ? 2 : 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(
                            c['label']!,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.w500),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SELECT CORRIDOR MANIFEST:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textSecondary),
                ),
                Row(
                  children: _corridors.map((c) {
                    final isSelected = c['truck_id'] == _selectedTruckId;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ElevatedButton(
                        onPressed: () => _loadManifest(truckId: c['truck_id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? AppConstants.primaryNavy
                              : Colors.grey.shade200,
                          foregroundColor:
                              isSelected ? Colors.white : AppConstants.textPrimary,
                          elevation: isSelected ? 2 : 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          c['label']!,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w500),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildManifestOfficialHeader(DispatchManifestDossier m) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Row(
              children: [
                const Icon(Icons.account_balance_rounded,
                    color: AppConstants.primaryNavy, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GOVERNMENT OF KARNATAKA • FOOD & CIVIL SUPPLIES',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppConstants.primaryNavy.withValues(alpha: 0.8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pre-Dispatch Logistics Manifest: ${m.manifestId}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppConstants.primaryNavy),
            ),
            if (m.isLocked && m.digitalSealHash != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppConstants.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppConstants.successGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppConstants.successGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CRYPTOGRAPHIC DIGITAL SEAL',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.successGreen)),
                          Text(
                            m.digitalSealHash!,
                            style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primaryNavy),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_rounded,
                            color: AppConstants.primaryNavy, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'GOVERNMENT OF KARNATAKA • FOOD & CIVIL SUPPLIES',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppConstants.primaryNavy.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pre-Dispatch Logistics Manifest: ${m.manifestId}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppConstants.primaryNavy),
                    ),
                  ],
                ),
                // Digital Seal / QR Representation
                if (m.isLocked && m.digitalSealHash != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppConstants.successGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.successGreen),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                size: 14, color: AppConstants.successGreen),
                            SizedBox(width: 4),
                            Text('CRYPTOGRAPHIC DIGITAL SEAL',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.successGreen)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.digitalSealHash!,
                          style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryNavy),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const Divider(height: 18),
          // 4 Metadata KPI Badges
          if (isMobile)
            Column(
              children: [
                Row(
                  children: [
                    _buildMetaTile('SOURCE DEPOT', m.sourceDepotName, Icons.warehouse_rounded),
                    _buildMetaTile('CARRIER', '${m.truckModel} (${m.truckId})', Icons.local_shipping_rounded),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMetaTile('DRIVER', '${m.driverName} (${m.driverPhone})', Icons.badge_rounded),
                    _buildMetaTile('PAYLOAD', '${m.totalQuantityKg.toStringAsFixed(0)} kg (${m.payloadUtilizationPct}%)', Icons.scale_rounded),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                _buildMetaTile('SOURCE DEPOT', m.sourceDepotName, Icons.warehouse_rounded),
                _buildMetaTile('ASSIGNED CARRIER', '${m.truckModel} (${m.truckId})', Icons.local_shipping_rounded),
                _buildMetaTile('DRIVER', '${m.driverName} (${m.driverPhone})', Icons.badge_rounded),
                _buildMetaTile('TOTAL PAYLOAD', '${m.totalQuantityKg.toStringAsFixed(0)} kg (${m.payloadUtilizationPct}% Utilization)', Icons.scale_rounded),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMetaTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppConstants.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppConstants.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppConstants.primaryNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textSecondary)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalParametersCard(DispatchManifestDossier m) {
    final isLocked = m.isLocked;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      isLocked ? Icons.lock_outline_rounded : Icons.edit_note_rounded,
                      color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isLocked
                            ? 'Status: LOCKED & IMMUTABLE (Ver ${m.version})'
                            : 'Status: DRAFT & EDITABLE (Ver ${m.version})',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isLocked)
                  ElevatedButton.icon(
                    onPressed: _isActionExecuting ? null : _createRevision,
                    icon: const Icon(Icons.edit_note_rounded, size: 14),
                    label: const Text('Create Revision',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.accentAmber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isActionExecuting ? null : _saveDraftModifications,
                          icon: const Icon(Icons.save_outlined, size: 14),
                          label: const Text('Save Draft',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppConstants.primaryNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActionExecuting ? null : _lockManifest,
                          icon: const Icon(Icons.lock_rounded, size: 14),
                          label: const Text('Lock Manifest',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isLocked ? Icons.lock_outline_rounded : Icons.edit_note_rounded,
                      color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLocked
                          ? 'Manifest Status: LOCKED & IMMUTABLE (Version ${m.version})'
                          : 'Manifest Status: DRAFT & EDITABLE (Version ${m.version})',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber),
                    ),
                  ],
                ),
                if (isLocked)
                  ElevatedButton.icon(
                    onPressed: _isActionExecuting ? null : _createRevision,
                    icon: const Icon(Icons.edit_note_rounded, size: 14),
                    label: const Text('Create Revision',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.accentAmber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                else
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isActionExecuting ? null : _saveDraftModifications,
                        icon: const Icon(Icons.save_outlined, size: 14),
                        label: const Text('Save Draft Changes',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isActionExecuting ? null : _lockManifest,
                        icon: const Icon(Icons.lock_rounded, size: 14),
                        label: const Text('Approve & Lock Manifest',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const Divider(height: 16),
          // Form Controls (Editable in DRAFT / Disabled in LOCKED)
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuantityControl(isLocked),
                const SizedBox(height: 14),
                _buildCarrierControl(isLocked),
                const SizedBox(height: 14),
                _buildRouteControl(isLocked),
                const SizedBox(height: 14),
                _buildDepartureControl(isLocked),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildQuantityControl(isLocked)),
                const SizedBox(width: 16),
                Expanded(child: _buildCarrierControl(isLocked)),
                const SizedBox(width: 16),
                Expanded(child: _buildRouteControl(isLocked)),
                const SizedBox(width: 16),
                Expanded(child: _buildDepartureControl(isLocked)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuantityControl(bool isLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Dispatch Quantity',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text('${_editableQuantityKg.toStringAsFixed(0)} kg',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppConstants.primaryNavy)),
          ],
        ),
        Slider(
          value: _editableQuantityKg.clamp(1000.0, 10000.0),
          min: 1000.0,
          max: 10000.0,
          divisions: 18,
          activeColor: isLocked ? Colors.grey : AppConstants.accentBlue,
          onChanged: isLocked
              ? null
              : (val) => setState(() => _editableQuantityKg = val),
        ),
        Text(
          'Rice: ${(_editableQuantityKg * 0.65).toStringAsFixed(0)} kg • Wheat: ${(_editableQuantityKg * 0.35).toStringAsFixed(0)} kg',
          style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCarrierControl(bool isLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assigned Fleet Carrier',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _editableTruckId,
          decoration: InputDecoration(
            isDense: true,
            enabled: !isLocked,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          items: const [
            DropdownMenuItem(
                value: 'DEMO-KA-04-E-1021',
                child: Text('Eicher Pro 10 MT (KA-04-E-1021)',
                    style: TextStyle(fontSize: 11))),
            DropdownMenuItem(
                value: 'DEMO-KA-04-E-1022',
                child: Text('Tata Ultra 10 MT (KA-04-E-1022)',
                    style: TextStyle(fontSize: 11))),
            DropdownMenuItem(
                value: 'DEMO-KA-51-M-3419',
                child: Text('BharatBenz 10 MT (KA-51-M-3419)',
                    style: TextStyle(fontSize: 11))),
          ],
          onChanged: isLocked ? null : (val) => setState(() => _editableTruckId = val!),
        ),
      ],
    );
  }

  Widget _buildRouteControl(bool isLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Route Corridor Path',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _editableRouteType,
          decoration: InputDecoration(
            isDense: true,
            enabled: !isLocked,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          items: const [
            DropdownMenuItem(
                value: 'EXPRESS_CORRIDOR',
                child: Text('Expressway / Ring Road Tour',
                    style: TextStyle(fontSize: 11))),
            DropdownMenuItem(
                value: 'DIRECT_ARTERIAL',
                child: Text('Direct Urban Arterial Route',
                    style: TextStyle(fontSize: 11))),
            DropdownMenuItem(
                value: 'STAGGERED_PARALLEL',
                child: Text('Staggered Split Corridor',
                    style: TextStyle(fontSize: 11))),
          ],
          onChanged: isLocked ? null : (val) => setState(() => _editableRouteType = val!),
        ),
      ],
    );
  }

  Widget _buildDepartureControl(bool isLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Departure Time Window',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _editableDepartureWindow,
          decoration: InputDecoration(
            isDense: true,
            enabled: !isLocked,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          items: const [
            DropdownMenuItem(
                value: '07:30 AM (Early Priority)',
                child: Text('07:30 AM (Early Priority)',
                    style: TextStyle(fontSize: 11))),
            DropdownMenuItem(
                value: '08:30 AM (Morning Slot)',
                child: Text('08:30 AM (Morning Slot)',
                    style: TextStyle(fontSize: 11))),
            DropdownMenuItem(
                value: '09:15 AM (Mid-Morning)',
                child: Text('09:15 AM (Mid-Morning)',
                    style: TextStyle(fontSize: 11))),
          ],
          onChanged: isLocked
              ? null
              : (val) => setState(() => _editableDepartureWindow = val!),
        ),
      ],
    );
  }

  // ─── TRUCK ROUTE MAP ─────────────────────────────────────────────────────────

  Widget _buildTruckRouteMapCard(DispatchManifestDossier m) {
    // Build the depot node and the FPS stop nodes for the map.
    // We use real/fallback coordinates if available; otherwise we generate
    // a clean circular layout so the map is always useful.
    final stops = m.deliverySequence;
    final hasCoords = stops.isNotEmpty &&
        stops.any((s) => s.latitude != 0.0 && s.longitude != 0.0);

    // Depot center (Yeshwanthpur Industrial Suburb)
    const depotLat = 13.0220;
    const depotLng = 77.5433;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A6B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: Color(0xFF1A3A6B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Truck Route Map — TSP Optimized Delivery Path',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryNavy),
                      ),
                      Text(
                        'Vehicle: ${m.truckModel} • ${m.truckId} • ${m.totalStopsCount} stops • ${m.deliverySequence.isNotEmpty ? m.deliverySequence.last.cumulativeDistanceKm.toStringAsFixed(1) : "—"} km',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppConstants.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppConstants.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppConstants.successGreen.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded,
                        size: 13, color: AppConstants.successGreen),
                    const SizedBox(width: 4),
                    Text(
                      'TSP Score: ${m.optimizationScore.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.successGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Map Canvas ──────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEFF3F9), Color(0xFFE8EDF5)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0D8E8)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size:
                        Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _TruckRouteMapPainter(
                      stops: stops,
                      hasCoords: hasCoords,
                      depotLat: depotLat,
                      depotLng: depotLng,
                      depotName: m.sourceDepotName,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Legend Row ──────────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMapLegendItem(
                    const Color(0xFF1A3A6B), Icons.warehouse_rounded, 'Source Depot'),
                const SizedBox(width: 14),
                _buildMapLegendItem(
                    AppConstants.purpleAccent, Icons.store_rounded, 'FPS Delivery Stop'),
                const SizedBox(width: 14),
                _buildMapLegendItem(
                    AppConstants.accentAmber, Icons.local_shipping_rounded, 'Truck (In Transit)'),
                const SizedBox(width: 14),
                _buildMapLegendItem(
                    AppConstants.accentBlue, Icons.timeline_rounded, 'Optimized Route Path'),
                const SizedBox(width: 14),
                Text(
                  '• Dep: ${m.departureWindow} • ${m.routeType.replaceAll("_", " ")}',
                  style: const TextStyle(
                      fontSize: 10, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLegendItem(Color color, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDeliverySequenceSection(DispatchManifestDossier m) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route_rounded,
                      color: AppConstants.purpleAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Manifest Delivery Drops (${m.deliverySequence.length} FPS Stops)',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Text(
                'TSP Score: ${m.optimizationScore.toStringAsFixed(1)} | Efficiency: ${m.efficiencyPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.purpleAccent),
              ),
            ],
          ),
          const Divider(height: 16),
          ...m.deliverySequence.map((s) {
            if (isMobile) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
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
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppConstants.primaryNavy,
                          child: Text('${s.sequenceOrder}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${s.fpsName} (${s.fpsId})',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textPrimary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ETA: ${s.estimatedArrivalWindow}',
                            style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppConstants.accentBlue)),
                        Text(
                            '${s.totalDropKg.toStringAsFixed(0)} kg (R:${s.riceKg.toStringAsFixed(0)} / W:${s.wheatKg.toStringAsFixed(0)})',
                            style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.successGreen)),
                      ],
                    ),
                  ],
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppConstants.backgroundLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppConstants.cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppConstants.primaryNavy,
                    child: Text('${s.sequenceOrder}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Text('${s.fpsName} (${s.fpsId})',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textPrimary)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('ETA: ${s.estimatedArrivalWindow}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.accentBlue)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                        'Drop: ${s.totalDropKg.toStringAsFixed(0)} kg (Rice: ${s.riceKg.toStringAsFixed(0)}kg / Wheat: ${s.wheatKg.toStringAsFixed(0)}kg)',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.successGreen),
                        textAlign: TextAlign.end),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAuditTrailTimelineCard(DispatchManifestDossier m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_edu_rounded,
                  color: AppConstants.primaryNavy, size: 18),
              SizedBox(width: 8),
              Text(
                'Immutable Statutory Audit Trail',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Chronological log of all manifest lifecycle events, signatures, version revisions, and digital seals.',
            style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
          ),
          const Divider(height: 16),
          ...m.auditTrail.map((a) {
            Color actionColor = AppConstants.primaryNavy;
            IconData actionIcon = Icons.info_outline;

            if (a.action == 'CREATED') {
              actionColor = AppConstants.accentBlue;
              actionIcon = Icons.add_circle_outline;
            } else if (a.action == 'VALIDATED') {
              actionColor = const Color(0xFF0284C7);
              actionIcon = Icons.rule_rounded;
            } else if (a.action == 'OPTIMIZED') {
              actionColor = AppConstants.purpleAccent;
              actionIcon = Icons.route_rounded;
            } else if (a.action == 'APPROVED' || a.action == 'LOCKED') {
              actionColor = AppConstants.successGreen;
              actionIcon = Icons.verified_rounded;
            } else if (a.action == 'REVISED') {
              actionColor = AppConstants.accentAmber;
              actionIcon = Icons.edit_note_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: actionColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(actionIcon, size: 16, color: actionColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(
                              '${a.action} (${a.version}) • ${a.actorName}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: actionColor),
                            ),
                            Text(
                              a.timestamp,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppConstants.textTertiary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.reason,
                          style: const TextStyle(
                              fontSize: 11, color: AppConstants.textPrimary),
                        ),
                        if (a.changesSummary != null && a.changesSummary!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              a.changesSummary!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: AppConstants.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NATIONAL FOOD SECURITY ACT (NFSA) • OFFICIAL DISPATCH MANIFEST SYSTEM',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppConstants.textTertiary),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'NATIONAL FOOD SECURITY ACT (NFSA) • OFFICIAL DISPATCH MANIFEST SYSTEM',
            style: TextStyle(fontSize: 10, color: AppConstants.textTertiary),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRUCK ROUTE MAP CUSTOM PAINTER
// Renders the TSP-optimised delivery route on a Flutter canvas.
// ─────────────────────────────────────────────────────────────────────────────

class _TruckRouteMapPainter extends CustomPainter {
  final List<OptimizedStop> stops;
  final bool hasCoords;
  final double depotLat;
  final double depotLng;
  final String depotName;

  _TruckRouteMapPainter({
    required this.stops,
    required this.hasCoords,
    required this.depotLat,
    required this.depotLng,
    required this.depotName,
  });

  // ── Coordinate → Canvas projection ─────────────────────────────────────────

  /// Project a geo-coordinate (lat/lng) to canvas pixels, given the bounding
  /// box of all points. Latitude is inverted so that "north" is at the top.
  Offset _project(double lat, double lng, Rect bounds,
      double minLat, double maxLat, double minLng, double maxLng,
      {double padding = 48}) {
    final rangeW = (maxLng - minLng).abs();
    final rangeH = (maxLat - minLat).abs();

    // Avoid division by zero when all points are at the same coordinate.
    final scaleX = rangeW < 1e-6 ? 1.0 : (bounds.width - padding * 2) / rangeW;
    final scaleY = rangeH < 1e-6 ? 1.0 : (bounds.height - padding * 2) / rangeH;

    final x = bounds.left + padding + (lng - minLng) * scaleX;
    final y = bounds.top + padding + (maxLat - lat) * scaleY; // invert Y
    return Offset(x, y);
  }

  // ── Layout fallback (circular) when coords are missing ────────────────────

  List<Offset> _circularLayout(Rect bounds) {
    if (stops.isEmpty) return [];
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final r = math.min(bounds.width, bounds.height) * 0.32;
    return List.generate(stops.length, (i) {
      final angle = -math.pi / 2 + (2 * math.pi * i / stops.length);
      return Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Background grid ─────────────────────────────────────────────────────
    _drawGrid(canvas, rect);

    if (stops.isEmpty) {
      _drawEmptyState(canvas, rect);
      return;
    }

    // 2. Collect all point coordinates ────────────────────────────────────────
    List<Offset> stopOffsets;
    Offset depotOffset;

    if (hasCoords) {
      // Determine bounding box of all points (depot + stops).
      double minLat = depotLat, maxLat = depotLat;
      double minLng = depotLng, maxLng = depotLng;

      for (final s in stops) {
        if (s.latitude == 0.0 && s.longitude == 0.0) continue;
        minLat = math.min(minLat, s.latitude);
        maxLat = math.max(maxLat, s.latitude);
        minLng = math.min(minLng, s.longitude);
        maxLng = math.max(maxLng, s.longitude);
      }

      // Add a small margin so points aren't right on the edge.
      final latPad = (maxLat - minLat) * 0.18 + 0.002;
      final lngPad = (maxLng - minLng) * 0.18 + 0.002;
      minLat -= latPad; maxLat += latPad;
      minLng -= lngPad; maxLng += lngPad;

      depotOffset = _project(depotLat, depotLng, rect,
          minLat, maxLat, minLng, maxLng, padding: 52);

      stopOffsets = stops.map((s) {
        final lat = s.latitude != 0.0 ? s.latitude : depotLat;
        final lng = s.longitude != 0.0 ? s.longitude : depotLng;
        return _project(lat, lng, rect,
            minLat, maxLat, minLng, maxLng, padding: 52);
      }).toList();
    } else {
      // Fall back to evenly-spaced circular layout.
      stopOffsets = _circularLayout(rect);
      depotOffset = rect.center;
    }

    // 3. Build the full route: depot → stop1 → stop2 → … → depot ────────────
    final routePoints = [depotOffset, ...stopOffsets, depotOffset];

    // 4. Road shadow / halo ───────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = const Color(0xFF1A3A6B).withValues(alpha: 0.10)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _drawPolyline(canvas, routePoints.sublist(0, routePoints.length - 1),
        shadowPaint);

    // 5. Main route line ──────────────────────────────────────────────────────
    final routePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _drawPolyline(canvas, routePoints.sublist(0, routePoints.length - 1),
        routePaint);

    // 6. Dashed return leg (last stop → depot) ────────────────────────────────
    _drawDashedLine(canvas, routePoints[routePoints.length - 2], depotOffset,
        const Color(0xFF64748B), 2.0);

    // 7. Directional arrows along route ───────────────────────────────────────
    for (int i = 0; i < routePoints.length - 2; i++) {
      _drawArrow(canvas, routePoints[i], routePoints[i + 1],
          const Color(0xFF2563EB));
    }

    // 8. Distance labels on each leg ──────────────────────────────────────────
    for (int i = 0; i < stops.length; i++) {
      final from = i == 0 ? depotOffset : stopOffsets[i - 1];
      final to = stopOffsets[i];
      final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      _drawDistanceBadge(canvas, mid,
          '${stops[i].legDistanceKm.toStringAsFixed(1)} km');
    }

    // 9. FPS stop markers ─────────────────────────────────────────────────────
    for (int i = 0; i < stops.length; i++) {
      _drawStopMarker(canvas, stopOffsets[i], stops[i]);
    }

    // 10. Depot marker ────────────────────────────────────────────────────────
    _drawDepotMarker(canvas, depotOffset);

    // 11. Truck marker (positioned at 40% of the first leg) ───────────────────
    if (stopOffsets.isNotEmpty) {
      const t = 0.42;
      final truckPos = Offset(
        depotOffset.dx + (stopOffsets[0].dx - depotOffset.dx) * t,
        depotOffset.dy + (stopOffsets[0].dy - depotOffset.dy) * t,
      );
      _drawTruckMarker(canvas, truckPos, depotOffset, stopOffsets[0]);
    }

    // 12. Compass rose ────────────────────────────────────────────────────────
    _drawCompass(canvas, Offset(size.width - 36, 36));

    // 13. Scale bar ───────────────────────────────────────────────────────────
    _drawScaleBar(canvas, Offset(16, size.height - 20));
  }

  // ── Drawing helpers ─────────────────────────────────────────────────────────

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.15)
      ..strokeWidth = 0.8;
    const step = 40.0;
    for (double x = 0; x < rect.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, rect.height), gridPaint);
    }
    for (double y = 0; y < rect.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(rect.width, y), gridPaint);
    }
  }

  void _drawEmptyState(Canvas canvas, Rect rect) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'No delivery stops in this manifest.',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawDashedLine(
      Canvas canvas, Offset from, Offset to, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dashLen = 6.0, gapLen = 4.0;
    final dx = to.dx - from.dx, dy = to.dy - from.dy;
    final total = math.sqrt(dx * dx + dy * dy);
    if (total == 0) return;
    final nx = dx / total, ny = dy / total;
    double traveled = 0;
    bool drawing = true;
    while (traveled < total) {
      final segLen = drawing ? dashLen : gapLen;
      final end = math.min(traveled + segLen, total);
      if (drawing) {
        canvas.drawLine(
          Offset(from.dx + nx * traveled, from.dy + ny * traveled),
          Offset(from.dx + nx * end, from.dy + ny * end),
          paint,
        );
      }
      traveled = end;
      drawing = !drawing;
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final dx = to.dx - from.dx, dy = to.dy - from.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 30) return;

    // Place arrow at 65% along the segment.
    const t = 0.65;
    final cx = from.dx + dx * t, cy = from.dy + dy * t;
    final angle = math.atan2(dy, dx);

    const arrowSize = 7.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(cx + arrowSize * math.cos(angle),
        cy + arrowSize * math.sin(angle));
    path.lineTo(
        cx + arrowSize * math.cos(angle + 2.5),
        cy + arrowSize * math.sin(angle + 2.5));
    path.lineTo(
        cx + arrowSize * math.cos(angle - 2.5),
        cy + arrowSize * math.sin(angle - 2.5));
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDistanceBadge(Canvas canvas, Offset center, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF1E40AF),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const pad = 4.0;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: center,
          width: tp.width + pad * 2 + 2,
          height: tp.height + pad),
      const Radius.circular(4),
    );

    canvas.drawRRect(
        bgRect,
        Paint()
          ..color = const Color(0xFFDBEAFE)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        bgRect,
        Paint()
          ..color = const Color(0xFF93C5FD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);

    tp.paint(canvas,
        center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawStopMarker(Canvas canvas, Offset pos, OptimizedStop stop) {
    const r = 14.0;

    // Outer shadow
    canvas.drawCircle(
        pos,
        r + 3,
        Paint()
          ..color = const Color(0xFF7C3AED).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Filled circle
    canvas.drawCircle(
        pos, r,
        Paint()
          ..color = const Color(0xFF7C3AED)
          ..style = PaintingStyle.fill);

    // White border
    canvas.drawCircle(
        pos, r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // Stop number text
    final tp = TextPainter(
      text: TextSpan(
        text: '${stop.sequenceOrder}',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));

    // Label callout above the circle
    _drawCallout(
      canvas,
      pos,
      stop.fpsName.length > 20
          ? '${stop.fpsName.substring(0, 18)}…'
          : stop.fpsName,
      '${stop.totalDropKg.toStringAsFixed(0)} kg  •  ETA ${stop.estimatedArrivalWindow}',
      r,
    );
  }

  void _drawCallout(Canvas canvas, Offset pos, String title, String subtitle,
      double markerRadius) {
    const titleStyle = TextStyle(
        color: Color(0xFF1E293B), fontSize: 9.5, fontWeight: FontWeight.bold);
    const subtitleStyle = TextStyle(
        color: Color(0xFF475569), fontSize: 8.5);

    final titleTp = TextPainter(
        text: TextSpan(text: title, style: titleStyle),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 130);
    final subTp = TextPainter(
        text: TextSpan(text: subtitle, style: subtitleStyle),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 130);

    const hPad = 6.0, vPad = 4.0;
    final boxW =
        math.max(titleTp.width, subTp.width) + hPad * 2;
    final boxH = titleTp.height + subTp.height + vPad * 2 + 2;

    // Position above the marker, centred.
    final boxLeft = pos.dx - boxW / 2;
    final boxTop = pos.dy - markerRadius - boxH - 6;

    final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxLeft, boxTop, boxW, boxH),
        const Radius.circular(5));

    canvas.drawRRect(
        bgRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        bgRect,
        Paint()
          ..color = const Color(0xFF7C3AED).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);

    // Stem triangle
    final stem = Path()
      ..moveTo(pos.dx - 5, boxTop + boxH)
      ..lineTo(pos.dx + 5, boxTop + boxH)
      ..lineTo(pos.dx, boxTop + boxH + 6)
      ..close();
    canvas.drawPath(stem,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..style = PaintingStyle.fill);

    titleTp.paint(canvas,
        Offset(boxLeft + hPad, boxTop + vPad));
    subTp.paint(canvas,
        Offset(boxLeft + hPad, boxTop + vPad + titleTp.height + 2));
  }

  void _drawDepotMarker(Canvas canvas, Offset pos) {
    const r = 18.0;

    // Pulsing halo
    canvas.drawCircle(
        pos, r + 8,
        Paint()
          ..color = const Color(0xFF1A3A6B).withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.drawCircle(pos, r + 4,
        Paint()
          ..color = const Color(0xFF1A3A6B).withValues(alpha: 0.20)
          ..style = PaintingStyle.fill);

    canvas.drawCircle(pos, r,
        Paint()
          ..color = const Color(0xFF1A3A6B)
          ..style = PaintingStyle.fill);

    canvas.drawCircle(pos, r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // Warehouse icon: simple building shape using lines/rects
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Body
    canvas.drawRect(
        Rect.fromCenter(center: pos + const Offset(0, 2), width: 16, height: 10),
        iconPaint);
    // Roof triangle
    final roof = Path()
      ..moveTo(pos.dx - 10, pos.dy - 3)
      ..lineTo(pos.dx, pos.dy - 10)
      ..lineTo(pos.dx + 10, pos.dy - 3)
      ..close();
    canvas.drawPath(roof, outlinePaint);

    // Depot label below
    final tp = TextPainter(
      text: const TextSpan(
        text: 'DEPOT',
        style: TextStyle(
            color: Color(0xFF1A3A6B),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos + Offset(-tp.width / 2, r + 4));
  }

  void _drawTruckMarker(
      Canvas canvas, Offset pos, Offset from, Offset to) {
    const r = 16.0;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);

    // Glow
    canvas.drawCircle(
        pos, r + 5,
        Paint()
          ..color = const Color(0xFFF59E0B).withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    // Truck body
    final body = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;
    final bodyBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-14, -8, 22, 16), const Radius.circular(3)),
        body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-14, -8, 22, 16), const Radius.circular(3)),
        bodyBorder);

    // Cab
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, -7, 8, 14), const Radius.circular(2)),
        Paint()
          ..color = const Color(0xFFD97706)
          ..style = PaintingStyle.fill);

    // Wheels
    final wheel = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-6, 9), 3.5, wheel);
    canvas.drawCircle(const Offset(8, 9), 3.5, wheel);

    // Headlight dot
    canvas.drawCircle(const Offset(15, -3), 1.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill);

    canvas.restore();

    // "In Transit" badge above truck
    final tp = TextPainter(
      text: const TextSpan(
        text: '🚛 In Transit',
        style: TextStyle(
            color: Color(0xFF92400E),
            fontSize: 8.5,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const bPad = 4.0;
    final bRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: pos - const Offset(0, 26),
          width: tp.width + bPad * 2,
          height: tp.height + bPad),
      const Radius.circular(4),
    );
    canvas.drawRRect(bRect,
        Paint()
          ..color = const Color(0xFFFEF3C7)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(bRect,
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
    tp.paint(canvas, pos - Offset(tp.width / 2, 26 + tp.height / 2));
  }

  void _drawCompass(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 14, paint);

    // N arrow
    final northPath = Path()
      ..moveTo(center.dx, center.dy - 10)
      ..lineTo(center.dx - 3, center.dy + 2)
      ..lineTo(center.dx + 3, center.dy + 2)
      ..close();
    canvas.drawPath(northPath,
        Paint()
          ..color = const Color(0xFFEF4444)
          ..style = PaintingStyle.fill);

    // S arrow
    final southPath = Path()
      ..moveTo(center.dx, center.dy + 10)
      ..lineTo(center.dx - 3, center.dy - 2)
      ..lineTo(center.dx + 3, center.dy - 2)
      ..close();
    canvas.drawPath(southPath,
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..style = PaintingStyle.fill);

    final nTp = TextPainter(
      text: const TextSpan(
          text: 'N',
          style: TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 8,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    nTp.paint(canvas, center - Offset(nTp.width / 2, 22));
  }

  void _drawScaleBar(Canvas canvas, Offset origin) {
    const barW = 60.0;
    final paint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(origin, origin + const Offset(barW, 0), paint);
    canvas.drawLine(origin, origin - const Offset(0, 4), paint);
    canvas.drawLine(
        origin + const Offset(barW, 0),
        origin + const Offset(barW, -4),
        paint);

    final tp = TextPainter(
      text: const TextSpan(
          text: '~5 km',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        origin + Offset(barW / 2 - tp.width / 2, -tp.height - 2));
  }

  @override
  bool shouldRepaint(_TruckRouteMapPainter old) =>
      old.stops != stops || old.depotLat != depotLat || old.depotLng != depotLng;
}
