import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// ─── AI Complaint Escalation System Dialog ──────────────────────────────────
/// Displays all complaints and AI-clustered grievance groups.
/// Unresolved clusters can be escalated to DSO as a single unified complaint.
class EscalationSystemDialog extends StatefulWidget {
  final ApiService apiService;

  const EscalationSystemDialog({super.key, required this.apiService});

  @override
  State<EscalationSystemDialog> createState() => _EscalationSystemDialogState();
}

class _EscalationSystemDialogState extends State<EscalationSystemDialog>
    with SingleTickerProviderStateMixin {
  // Colors
  static const Color _navy = Color(0xFF0F2942);
  static const Color _green = Color(0xFF15803D);
  static const Color _red = Color(0xFFDC2626);
  static const Color _amber = Color(0xFFD97706);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate300 = Color(0xFFCBD5E1);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate50 = Color(0xFFF8FAFC);

  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _clusters = [];

  bool _showSubmitForm = false;
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _selectedCategory = 'GENERAL';
  String _selectedFpsId = 'FPS-KA-BAG-0001';
  bool _isSubmitting = false;
  String? _escalatingClusterId;

  static const _categoryLabels = {
    'SHORT_WEIGHT': 'Short Weight',
    'SHOP_CLOSED': 'Shop Closed',
    'RATION_QUALITY': 'Ration Quality',
    'DELIVERY_DELAY': 'Delivery Delay',
    'OVERCHARGING': 'Overcharging',
    'GENERAL': 'General',
  };

  static const _categoryColors = {
    'SHORT_WEIGHT': Color(0xFFDC2626),
    'SHOP_CLOSED': Color(0xFFD97706),
    'RATION_QUALITY': Color(0xFFB45309),
    'DELIVERY_DELAY': Color(0xFF2563EB),
    'OVERCHARGING': Color(0xFF7C3AED),
    'GENERAL': Color(0xFF64748B),
  };

  static const _severityColors = {
    'HIGH': Color(0xFFDC2626),
    'MEDIUM': Color(0xFFD97706),
    'LOW': Color(0xFF15803D),
  };

  static const _escalationColors = {
    'ESCALATED': Color(0xFF15803D),
    'PENDING': Color(0xFFD97706),
    'RESOLVED': Color(0xFF64748B),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await widget.apiService.fetchEscalationAnalysis();
      setState(() {
        _summary = (data['summary'] as Map<String, dynamic>?) ?? {};
        _complaints = ((data['complaints'] as List<dynamic>?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _clusters = ((data['clusters'] as List<dynamic>?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _escalateCluster(String clusterId) async {
    setState(() => _escalatingClusterId = clusterId);
    try {
      await widget.apiService.escalateCluster(clusterId: clusterId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Cluster escalated to DSO successfully!'),
            ]),
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 3),
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Escalation failed: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _escalatingClusterId = null);
    }
  }

  Future<void> _submitComplaint() async {
    if (_subjectCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in subject and message.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.apiService.submitFeedback(
        senderType: 'BENEFICIARY',
        senderId: 'BEN-DEMO-001',
        targetFpsId: _selectedFpsId,
        category: _selectedCategory,
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      _subjectCtrl.clear();
      _messageCtrl.clear();
      setState(() { _showSubmitForm = false; _isSubmitting = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted successfully!'), backgroundColor: Color(0xFF15803D)),
      );
      await _loadData();
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: _red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: 900,
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _buildErrorState()
            else ...[
              _buildSummaryBar(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildComplaintsTab(), _buildClustersTab()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2942), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.escalator_warning_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Grievance Escalation System', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              Text('Complaint clustering, pattern detection & DSO escalation', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), tooltip: 'Refresh', onPressed: _loadData),
          IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final stats = [
      ('Total', _summary['total_complaints']?.toString() ?? '0', const Color(0xFF334155)),
      ('Unresolved', _summary['unresolved_complaints']?.toString() ?? '0', _red),
      ('Clusters', _summary['total_clusters']?.toString() ?? '0', const Color(0xFF2563EB)),
      ('Escalated', _summary['escalated_clusters']?.toString() ?? '0', _green),
      ('Needs Escalation', _summary['pending_escalation']?.toString() ?? '0', _amber),
    ];
    return Container(
      color: _slate50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ...stats.map((s) => Expanded(child: _buildStatPill(s.$1, s.$2, s.$3))),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showSubmitForm = !_showSubmitForm),
            icon: Icon(_showSubmitForm ? Icons.close : Icons.add_rounded, size: 14, color: _navy),
            label: Text(_showSubmitForm ? 'Cancel' : 'Submit Complaint',
                style: const TextStyle(fontSize: 11, color: _navy, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _navy),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9.5, color: _slate500)),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _navy,
        unselectedLabelColor: _slate500,
        indicatorColor: _navy,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.list_alt_rounded, size: 16), const SizedBox(width: 6),
            Text('All Complaints (${_complaints.length})'),
          ])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.hub_rounded, size: 16), const SizedBox(width: 6),
            Text('Clustered Escalations (${_clusters.length})'),
          ])),
        ],
      ),
    );
  }

  Widget _buildSubmitForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.edit_note_rounded, size: 18, color: _green), SizedBox(width: 6),
          Text('Submit New Complaint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate900)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: InputDecorator(
              decoration: _inputDecoration('Category'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: _slate900),
                  items: _categoryLabels.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'GENERAL'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              initialValue: _selectedFpsId,
              decoration: _inputDecoration('Target FPS ID'),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) => _selectedFpsId = v,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(controller: _subjectCtrl, decoration: _inputDecoration('Complaint Subject'), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        TextField(controller: _messageCtrl, maxLines: 3, decoration: _inputDecoration('Detailed Complaint Description'), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitComplaint,
            icon: _isSubmitting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 14),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Complaint'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green, foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ]),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11.5, color: _slate500),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate300)),
    );
  }

  Widget _buildComplaintsTab() {
    return Container(
      color: _slate50,
      child: Column(children: [
        if (_showSubmitForm) _buildSubmitForm(),
        if (_complaints.isEmpty)
          const Expanded(child: Center(child: Text('No complaints found.', style: TextStyle(color: _slate500))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _complaints.length,
              itemBuilder: (ctx, i) => _buildComplaintCard(_complaints[i]),
            ),
          ),
      ]),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> ticket) {
    final category = ticket['category'] as String? ?? 'GENERAL';
    final status = ticket['status'] as String? ?? 'OPEN';
    final catColor = _categoryColors[category] ?? _slate500;
    final statusColor = status == 'RESOLVED' ? _green : status == 'UNDER_INVESTIGATION' ? _amber : _red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _chip(_categoryLabels[category] ?? category, catColor),
          const SizedBox(width: 6),
          _chip(status, statusColor),
          const Spacer(),
          Text(ticket['ticket_id']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: _slate500, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Text(ticket['target_fps_id']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: _slate500)),
        ]),
        const SizedBox(height: 7),
        Text(ticket['subject']?.toString() ?? '', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _slate900)),
        const SizedBox(height: 4),
        Text(ticket['message']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: _slate700)),
        const SizedBox(height: 5),
        Row(children: [
          const Icon(Icons.person_outline, size: 12, color: _slate500), const SizedBox(width: 3),
          Text(ticket['sender_id']?.toString() ?? '', style: const TextStyle(fontSize: 10.5, color: _slate500)),
          const SizedBox(width: 8),
          const Icon(Icons.access_time, size: 12, color: _slate500), const SizedBox(width: 3),
          Text((ticket['created_at']?.toString() ?? '').split('T').first, style: const TextStyle(fontSize: 10.5, color: _slate500)),
        ]),
      ]),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildClustersTab() {
    if (_clusters.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.hub_rounded, size: 48, color: _slate300),
          const SizedBox(height: 12),
          const Text('No complaint clusters yet.', style: TextStyle(color: _slate500, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Clusters form when multiple similar complaints are submitted.', style: TextStyle(color: _slate500, fontSize: 12)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _clusters.length,
      itemBuilder: (ctx, i) => _buildClusterCard(_clusters[i]),
    );
  }

  Widget _buildClusterCard(Map<String, dynamic> cluster) {
    final category = cluster['category'] as String? ?? 'GENERAL';
    final severity = cluster['severity'] as String? ?? 'MEDIUM';
    final escalationStatus = cluster['escalation_status'] as String? ?? 'PENDING';
    final count = cluster['complaint_count'] as int? ?? 0;
    final catColor = _categoryColors[category] ?? _slate500;
    final sevColor = _severityColors[severity] ?? _amber;
    final escColor = _escalationColors[escalationStatus] ?? _amber;
    final isEscalated = escalationStatus == 'ESCALATED';
    final isEscalatingThis = _escalatingClusterId == cluster['cluster_id'];
    final ticketIds = (cluster['ticket_ids'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isEscalated ? const Color(0xFF86EFAC) : _slate300, width: isEscalated ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isEscalated ? const Color(0xFFF0FDF4) : catColor.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: catColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: Text('$count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: catColor))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cluster['cluster_label']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
                Text('$count complaint${count != 1 ? 's' : ''} • ${cluster['primary_fps_id'] ?? 'Multiple FPS'}', style: const TextStyle(fontSize: 11, color: _slate500)),
              ]),
            ),
            _chip('⚠ $severity', sevColor),
            const SizedBox(width: 6),
            _chip(escalationStatus, escColor),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // AI badge
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AI ANALYSIS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 6),
              Text(cluster['cluster_id']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: _slate500, fontFamily: 'monospace')),
            ]),
            const SizedBox(height: 8),
            // AI Summary
            Text(cluster['ai_summary']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: _slate700, height: 1.5)),
            // Ticket ID chips
            if (ticketIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: [
                  ...ticketIds.take(6).map((tid) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(4)),
                    child: Text(tid.toString(), style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: _slate700)),
                  )),
                  if (ticketIds.length > 6)
                    Text('+${ticketIds.length - 6} more', style: const TextStyle(fontSize: 10, color: _slate500)),
                ],
              ),
            ],
            // Escalated note
            if (isEscalated && cluster['escalated_at'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check_circle, size: 14, color: _green), const SizedBox(width: 4),
                Text(
                  'Escalated to DSO on ${(cluster['escalated_at']?.toString() ?? '').split('T').first}',
                  style: const TextStyle(fontSize: 11, color: _green, fontWeight: FontWeight.w600),
                ),
              ]),
            ],
            // Escalate button
            if (!isEscalated) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton.icon(
                  onPressed: isEscalatingThis ? null : () => _escalateCluster(cluster['cluster_id']?.toString() ?? ''),
                  icon: isEscalatingThis
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded, size: 14),
                  label: Text(
                    isEscalatingThis ? 'Escalating...' : 'Escalate $count complaint${count != 1 ? 's' : ''} to DSO',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildErrorState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _red),
            const SizedBox(height: 12),
            const Text('Failed to load escalation data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text(_error ?? 'Unknown error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _slate500)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }
}
