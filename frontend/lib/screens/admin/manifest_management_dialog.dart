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
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: 1160,
        height: 840,
        padding: const EdgeInsets.all(22),
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
                        onPressed: () => _loadManifest(),
                        child: const Text('Retry Manifest Generation'),
                      )
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLocked
                    ? AppConstants.successGreen.withValues(alpha: 0.12)
                    : AppConstants.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLocked ? Icons.verified_rounded : Icons.description_rounded,
                color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'PDS Pre-Dispatch Manifest & Auditable Lock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                const Text(
                  'End-to-End Workflow: Forecast → Recommended Quantity → 9 Constraints → Optimization → LOCKED MANIFEST',
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

  Widget _buildScrollableBody() {
    final m = _manifest!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // 5. Itemized FPS Delivery Sequence Stops
          _buildDeliverySequenceSection(m),
          const SizedBox(height: 14),

          // 6. Immutable Audit Trail Timeline Card
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    );
  }

  Widget _buildCorridorSelectorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Row(
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isLocked ? AppConstants.successGreen : AppConstants.accentAmber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Quantity Slider / Field
              Expanded(
                child: Column(
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
                ),
              ),
              const SizedBox(width: 16),
              // 2. Assigned Carrier Dropdown
              Expanded(
                child: Column(
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
                ),
              ),
              const SizedBox(width: 16),
              // 3. Route Corridor Type Dropdown
              Expanded(
                child: Column(
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
                ),
              ),
              const SizedBox(width: 16),
              // 4. Departure Window
              Expanded(
                child: Column(
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySequenceSection(DispatchManifestDossier m) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Notice: DEMO DATA — NOT GOVERNMENT DATA (AUDITABLE MANIFEST ENGINE)',
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
