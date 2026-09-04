import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../core/constants.dart';
import '../../models/beneficiary_model.dart';

class CitizenRequestQueueDialog extends StatefulWidget {
  final String cycleId;
  final ApiService? apiService;
  const CitizenRequestQueueDialog({
    super.key,
    this.cycleId = '2026-09',
    this.apiService,
  });

  @override
  State<CitizenRequestQueueDialog> createState() => _CitizenRequestQueueDialogState();
}

class _CitizenRequestQueueDialogState extends State<CitizenRequestQueueDialog> with SingleTickerProviderStateMixin {
  late final ApiService _apiService;
  bool _isLoading = true;
  String? _errorMessage;
  CitizenRequestQueueResponse? _queueData;
  List<DeliveryDisputeModel> _disputes = [];
  String _selectedStatusFilter = 'ALL';
  String _searchQuery = '';
  late TabController _tabController;

  // Officer Action Form State per request
  final Map<String, String> _selectedDecisions = {};
  final Map<String, TextEditingController> _justificationControllers = {};
  final Map<String, TextEditingController> _customQtyControllers = {};
  final Map<String, String> _officerNames = {};
  final Map<String, String> _officerRoles = {};
  final Map<String, bool> _isSubmitting = {};

  final List<String> _statusTabs = [
    'ALL',
    'PENDING_OFFICER_REVIEW',
    'OFFICER_APPROVED',
    'DELAYED',
    'OFFICER_PARTIAL_APPROVED',
    'OFFICER_REDIRECTED',
    'OFFICER_DEFERRED',
    'DELIVERY_DISPUTES',
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedStatusFilter = _statusTabs[_tabController.index];
        });
        _loadQueueData();
      }
    });
    _loadQueueData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _justificationControllers.values) {
      controller.dispose();
    }
    for (var controller in _customQtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQueueData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.fetchCitizenRequestsQueue(
        cycleId: widget.cycleId,
        status: (_selectedStatusFilter == 'ALL' || _selectedStatusFilter == 'DELIVERY_DISPUTES') ? null : _selectedStatusFilter,
      );
      List<DeliveryDisputeModel> disputesList = [];
      try {
        disputesList = await _apiService.fetchDeliveryDisputes(cycleId: widget.cycleId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _queueData = res;
          _disputes = disputesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitAuthorization(CitizenRequestModel item) async {
    final decision = _selectedDecisions[item.requestId] ?? (item.aiRecommendation ?? 'APPROVE');
    final justification = _justificationControllers[item.requestId]?.text.trim() ?? '';
    final officerName = _officerNames[item.requestId] ?? 'K. Srinivas Murthy (DSO)';
    final officerRole = _officerRoles[item.requestId] ?? 'DISTRICT_SUPPLY_OFFICER';

    if (justification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mandatory: Please provide an official government justification for this decision.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    double? customQty;
    if (decision == 'PARTIAL_ALLOCATION') {
      final text = _customQtyControllers[item.requestId]?.text.trim();
      customQty = text != null && text.isNotEmpty ? double.tryParse(text) : item.aiRecommendedQtyKg;
    }

    setState(() => _isSubmitting[item.requestId] = true);

    try {
      await _apiService.authorizeCitizenRequest(
        requestId: item.requestId,
        officerName: officerName,
        officerRole: officerRole,
        decision: decision,
        allocatedQuantityKg: customQty,
        allocatedFpsId: decision == 'REDIRECT_ALTERNATIVE_FPS' ? item.aiRecommendedFpsId : null,
        officerJustification: justification,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${item.requestId} authorized successfully as $decision'),
          backgroundColor: AppConstants.successGreen,
        ),
      );
      await _loadQueueData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authorization failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting[item.requestId] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1160,
        height: 840,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildMetricsOverview(),
            _buildTabBar(),
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _buildRequestsList(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppConstants.primaryNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Citizen Preference & Request Review Queue',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppConstants.accentAmber.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppConstants.accentAmber, width: 1),
                      ),
                      child: Text(
                        'CYCLE ${widget.cycleId}',
                        style: const TextStyle(color: AppConstants.accentAmber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Institutional Decision Support: Citizen Request → AI Assessment → Officer Authorization → Downstream Dispatch',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh Queue',
            onPressed: _loadQueueData,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsOverview() {
    if (_queueData == null) return const SizedBox.shrink();
    return Column(
      children: [
        // 10-Stage End-to-End Lifecycle Stepper Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              const Icon(Icons.hub_outlined, color: AppConstants.accentAmber, size: 16),
              const SizedBox(width: 8),
              const Text(
                'END-TO-END GOVERNANCE LIFECYCLE:',
                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildLifecycleStepChip('1. Citizen Request', true, Colors.teal),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('2. AI Assessment', true, Colors.blue),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('3. Officer Decision', true, Colors.orange),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('4. Demand Lock', true, Colors.indigo),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('5. 9-Rule Constraints', false, Colors.cyan),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('6. TSP Optimization', false, Colors.purple),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('7. Manifest Lock', false, Colors.green),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('8. Gatepass Slip', false, Colors.deepPurple),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('9. Fleet Dispatch', false, Colors.amber),
                      _buildLifecycleArrow(),
                      _buildLifecycleStepChip('10. Immutable Audit', false, Colors.teal),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Metrics Summary Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricBadge('Total Submissions', '${_queueData!.totalCount}', Colors.blueGrey),
                const SizedBox(width: 14),
                _buildMetricBadge('Pending DSO Action', '${_queueData!.pendingCount}', Colors.orange, isHighlighted: true),
                const SizedBox(width: 14),
                _buildMetricBadge('Fully Approved', '${_queueData!.approvedCount}', AppConstants.successGreen),
                const SizedBox(width: 14),
                _buildMetricBadge('Partial Allocation', '${_queueData!.partialCount}', Colors.indigo),
                const SizedBox(width: 14),
                _buildMetricBadge('Alternative FPS', '${_queueData!.redirectedCount}', Colors.purple),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.gavel_rounded, size: 13, color: AppConstants.primaryNavy),
                      SizedBox(width: 6),
                      Text(
                        'NFSA Quotas & Statutory Floors Protected',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLifecycleStepChip(String label, bool isCurrentStage, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isCurrentStage ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isCurrentStage ? color : Colors.white24, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isCurrentStage ? Colors.white : Colors.white54,
          fontSize: 9.5,
          fontWeight: isCurrentStage ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildLifecycleArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right, color: Colors.white30, size: 14),
    );
  }

  Widget _buildMetricBadge(String label, String value, Color color, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHighlighted ? color : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppConstants.primaryNavy,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: AppConstants.primaryNavy,
        indicatorWeight: 3,
        tabs: [
          Tab(text: 'All Requests (${_queueData?.totalCount ?? 0})'),
          Tab(text: 'Pending Review (${_queueData?.pendingCount ?? 0})'),
          Tab(text: 'Approved (${_queueData?.approvedCount ?? 0})'),
          Tab(text: 'Delayed (${_queueData?.delayedCount ?? 0})'),
          Tab(text: 'Partial Allocation (${_queueData?.partialCount ?? 0})'),
          Tab(text: 'Redirected (${_queueData?.redirectedCount ?? 0})'),
          Tab(text: 'Deferred (${_queueData?.deferredCount ?? 0})'),
          Tab(text: 'Delivery Disputes (${_disputes.length})'),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Beneficiary ID, FPS name, or Commodity...',
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(width: 14),
          const Text('Advisory Mode: Human-In-The-Loop AI Guidance', style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_errorMessage ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadQueueData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_selectedStatusFilter == 'DELIVERY_DISPUTES') {
      return _buildDisputesList();
    }

    final items = (_queueData?.items ?? []).where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.requestId.toLowerCase().contains(_searchQuery) ||
          item.beneficiaryId.toLowerCase().contains(_searchQuery) ||
          item.beneficiaryName.toLowerCase().contains(_searchQuery) ||
          item.intendedFpsName.toLowerCase().contains(_searchQuery) ||
          item.registeredFpsName.toLowerCase().contains(_searchQuery) ||
          item.commodity.toLowerCase().contains(_searchQuery);
    }).toList();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _selectedStatusFilter == 'PENDING_OFFICER_REVIEW'
                  ? 'All citizen requests have been reviewed and authorized!'
                  : 'No requests found matching current filter criteria.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _buildRequestCard(items[index]);
      },
    );
  }

  Widget _buildDisputesList() {
    if (_disputes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_outlined, size: 48, color: Colors.green.shade400),
            const SizedBox(height: 12),
            const Text(
              'No delivery shortfall or discrepancy disputes filed for this cycle.',
              style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: _disputes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final d = _disputes[index];
        final isResolved = d.status == 'OFFICER_RESOLVED';

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isResolved ? Colors.green.shade300 : Colors.orange.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(d.disputeId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Text('• Req: ${d.requestId}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isResolved ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isResolved ? Colors.green.shade300 : Colors.orange.shade400),
                      ),
                      child: Text(
                        d.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isResolved ? Colors.green.shade800 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Beneficiary: ${d.beneficiaryId} • Commodity: ${d.commodity}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDisputeMetric('Allocated Quota', '${d.allocatedQuantityKg} kg', Colors.black87),
                      _buildDisputeMetric('Actual Received', '${d.receivedQuantityKg} kg', Colors.blueGrey),
                      _buildDisputeMetric('Shortfall / Variance', '${d.shortfallKg} kg', Colors.red.shade700),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Citizen Dispute Notes: "${d.disputeNotes}"',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade800),
                ),
                if (d.resolutionNotes != null && d.resolutionNotes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'DSO Resolution: ${d.resolutionNotes} (By: ${d.resolvedBy ?? "DSO"})',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade900),
                    ),
                  ),
                ],
                if (!isResolved) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => _showResolveDisputeDialog(d),
                      icon: const Icon(Icons.gavel, size: 16),
                      label: const Text('Resolve Dispute & Issue Directive', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisputeMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _showResolveDisputeDialog(DeliveryDisputeModel dispute) {
    final notesCtrl = TextEditingController();
    String decision = 'OFFICER_RESOLVED';
    bool isSubmitting = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: AppConstants.primaryNavy),
                const SizedBox(width: 8),
                Text('Resolve Dispute: ${dispute.disputeId}', style: const TextStyle(fontSize: 15)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shortfall of ${dispute.shortfallKg} kg ${dispute.commodity} reported for Beneficiary ${dispute.beneficiaryId}.',
                    style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: decision,
                    decoration: const InputDecoration(labelText: 'Officer Determination', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'OFFICER_RESOLVED', child: Text('Authorize Immediate Replenishment / Rectification')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Reject Dispute (Weighment Log Matches Authorized Quota)')),
                    ],
                    onChanged: (val) => setDialogState(() => decision = val ?? 'OFFICER_RESOLVED'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Official Resolution & Rectification Directive *',
                      hintText: 'e.g., Shortfall verified. Directed FPS dealer to issue remaining 5kg Rice immediately.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (notesCtrl.text.trim().isEmpty) {
                          setDialogState(() => error = 'Resolution notes are mandatory.');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          error = null;
                        });
                        try {
                          await _apiService.resolveDeliveryDispute(
                            disputeId: dispute.disputeId,
                            decision: decision,
                            resolutionNotes: notesCtrl.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadQueueData();
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            error = e.toString();
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryNavy, foregroundColor: Colors.white),
                child: const Text('Record Government Resolution'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(CitizenRequestModel item) {
    final isPortability = item.registeredFpsId != item.intendedFpsId;
    final isPending = item.status == 'PENDING_OFFICER_REVIEW';

    // Initialize controllers if not existing
    _justificationControllers.putIfAbsent(item.requestId, () => TextEditingController(text: item.officerJustification ?? ''));
    _customQtyControllers.putIfAbsent(item.requestId, () => TextEditingController(text: item.aiRecommendedQtyKg.toStringAsFixed(1)));
    _selectedDecisions.putIfAbsent(item.requestId, () => item.aiRecommendation ?? 'APPROVE');
    _officerNames.putIfAbsent(item.requestId, () => 'K. Srinivas Murthy (DSO)');
    _officerRoles.putIfAbsent(item.requestId, () => 'DISTRICT_SUPPLY_OFFICER');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isPending ? Colors.orange.shade200 : Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Request ID, Card Type, Status Badge
            Row(
              children: [
                Text(
                  item.requestId,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppConstants.primaryNavy),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    '${item.cardType} (${item.familyMembersCount} Members)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                  ),
                ),
                const SizedBox(width: 8),
                if (isPortability)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.purple.shade300)),
                    child: const Text('ONORC Portability Signal', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                  ),
                const Spacer(),
                _buildStatusBadge(item.status),
              ],
            ),
            const SizedBox(height: 12),

            // Beneficiary & FPS Route Header
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.person_pin, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${item.beneficiaryName} (${item.beneficiaryId})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      'Household: ${item.familyMembersCount} Members',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppConstants.accentBlue),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.storefront, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('Home: ${item.registeredFpsName}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_right_alt, color: AppConstants.primaryNavy, size: 18),
                  const SizedBox(width: 6),
                  Text('Intended: ${item.intendedFpsName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPortability ? Colors.purple.shade800 : Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Metrics Strip (Card Quota, Requested Qty, Target Inventory & Floor, Replenishment Window, Capacity, Demand, Alt FPS)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'Statutory Quota',
                          '${(item.familyMembersCount * 5.0).toStringAsFixed(1)} kg (${item.familyMembersCount} × 5 kg)',
                          Icons.gavel,
                          Colors.blue.shade700,
                        ),
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildMetricTile(
                          'Requested Intent',
                          '${item.requestedQuantityKg.toStringAsFixed(1)} kg',
                          Icons.touch_app,
                          AppConstants.primaryNavy,
                        ),
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildMetricTile(
                          'Shop Stock / Statutory Floor',
                          '${item.currentInventoryKg.toStringAsFixed(0)} kg / ${item.statutoryFloorKg.toStringAsFixed(0)} kg',
                          Icons.inventory_2_outlined,
                          Colors.teal.shade700,
                        ),
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildMetricTile(
                          'Replenishment Window',
                          item.replenishmentEta,
                          Icons.local_shipping_outlined,
                          Colors.indigo.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'FPS Storage & Headroom',
                          '${item.fpsCapacityKg.toStringAsFixed(0)} kg (Headroom: ${item.capacityHeadroomKg.toStringAsFixed(0)} kg)',
                          Icons.warehouse_outlined,
                          Colors.blueGrey.shade700,
                        ),
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildMetricTile(
                          'Pending Cycle Demand',
                          '${item.pendingDemandKg.toStringAsFixed(0)} kg',
                          Icons.pending_actions_outlined,
                          Colors.orange.shade800,
                        ),
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildMetricTile(
                          'Nearby Alternative FPS',
                          item.nearbyAlternativeFpsName != null
                              ? '${item.nearbyAlternativeFpsName} (${item.nearbyAlternativeDistanceKm?.toStringAsFixed(1) ?? "2.4"} km)'
                              : 'None required (Stock Adequate)',
                          Icons.alt_route_rounded,
                          Colors.purple.shade700,
                        ),
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildMetricTile(
                          'AI Decision Advisory',
                          '${item.aiRecommendation ?? "APPROVE"} • ${(item.aiConfidence * 100).toInt()}% Conf',
                          Icons.psychology_outlined,
                          Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // AI Decision-Support Advisory Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.smart_toy_outlined, size: 16, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      const Text(
                        'AI Decision-Support Recommendation (Advisory Only):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(width: 8),
                      _buildRecommendationPill(item.aiRecommendation ?? 'APPROVE'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
                        child: Text(
                          '${(item.aiConfidence * 100).toInt()}% Confidence • ${item.aiRiskLevel ?? 'LOW'} RISK',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                      ),
                      if (item.aiRecommendedFpsName != null && item.aiRecommendation == 'REDIRECT_ALTERNATIVE_FPS') ...[
                        const SizedBox(width: 8),
                        Text(
                          'Alt FPS: ${item.aiRecommendedFpsName}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.aiFactors.map((factor) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                        child: Text('• $factor', style: TextStyle(fontSize: 10, color: Colors.grey.shade800)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // If already authorized, show authorized officer record
            if (item.officerName != null && !isPending) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, size: 16, color: AppConstants.successGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Authorized by ${item.officerName} (${item.officerRole}) on ${item.authorizedAt ?? ''}. Allocation: ${item.authorizedQuantityKg.toStringAsFixed(1)} kg. Note: ${item.officerJustification ?? 'Approved'}',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // If pending review, show action sheet
            if (isPending) ...[
              const Divider(height: 20),
              _buildOfficerActionSheet(item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'OFFICER_APPROVED':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = 'OFFICER APPROVED';
        break;
      case 'OFFICER_PARTIAL_APPROVED':
        bg = Colors.indigo.shade100;
        fg = Colors.indigo.shade800;
        label = 'PARTIAL ALLOCATED';
        break;
      case 'OFFICER_REDIRECTED':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade800;
        label = 'REDIRECTED ALT FPS';
        break;
      case 'OFFICER_DEFERRED':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'DEFERRED';
        break;
      case 'REJECTED':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'REJECTED';
        break;
      case 'PENDING_OFFICER_REVIEW':
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        label = 'PENDING DSO ACTION';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildRecommendationPill(String recommendation) {
    Color color;
    switch (recommendation) {
      case 'APPROVE':
        color = AppConstants.successGreen;
        break;
      case 'PARTIAL_ALLOCATION':
        color = Colors.indigo;
        break;
      case 'REDIRECT_ALTERNATIVE_FPS':
        color = Colors.purple;
        break;
      case 'DEFER_TO_CYCLE':
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(recommendation, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfficerActionSheet(CitizenRequestModel item) {
    final currentDecision = _selectedDecisions[item.requestId] ?? 'APPROVE';
    final isBusy = _isSubmitting[item.requestId] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              const Text('Authorized Government Action:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Spacer(),
              // Decision Selector Buttons
              _buildDecisionButton(item, 'APPROVE', 'Full Quota', Colors.green),
              const SizedBox(width: 6),
              _buildDecisionButton(item, 'PARTIAL_ALLOCATION', 'Partial (${item.aiRecommendedQtyKg.toStringAsFixed(0)}kg)', Colors.indigo),
              const SizedBox(width: 6),
              _buildDecisionButton(item, 'REDIRECT_ALTERNATIVE_FPS', 'Redirect FPS', Colors.purple),
              const SizedBox(width: 6),
              _buildDecisionButton(item, 'DEFER_TO_CYCLE', 'Defer', Colors.orange),
            ],
          ),
          const SizedBox(height: 10),

          // Action input controls
          Row(
            children: [
              // If partial allocation, show custom qty input
              if (currentDecision == 'PARTIAL_ALLOCATION') ...[
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _customQtyControllers[item.requestId],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Allocated (kg)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Officer Justification Field
              Expanded(
                child: TextField(
                  controller: _justificationControllers[item.requestId],
                  decoration: InputDecoration(
                    hintText: 'Mandatory: Enter official justification / statutory rationale...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Officer Role / Name
              DropdownButton<String>(
                value: _officerNames[item.requestId] ?? 'K. Srinivas Murthy (DSO)',
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'K. Srinivas Murthy (DSO)', child: Text('K. Srinivas Murthy (DSO)', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'Basavaraj V. (Depot Mgr)', child: Text('Basavaraj V. (Depot Mgr)', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'District Admin', child: Text('District Admin', style: TextStyle(fontSize: 11))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _officerNames[item.requestId] = val;
                      _officerRoles[item.requestId] = val.contains('Depot') ? 'DEPOT_MANAGER' : 'DISTRICT_SUPPLY_OFFICER';
                    });
                  }
                },
              ),
              const SizedBox(width: 10),

              // Submit Button
              ElevatedButton.icon(
                onPressed: isBusy ? null : () => _submitAuthorization(item),
                icon: isBusy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 14),
                label: const Text('Authorize', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionButton(CitizenRequestModel item, String decisionKey, String label, Color color) {
    final isSelected = (_selectedDecisions[item.requestId] ?? (item.aiRecommendation ?? 'APPROVE')) == decisionKey;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDecisions[item.requestId] = decisionKey;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Citizen requests act as planning signals. Only authorized officer allocations flow downstream to dispatch optimization.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
