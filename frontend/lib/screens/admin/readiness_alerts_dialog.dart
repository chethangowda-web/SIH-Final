import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class ReadinessAlertsDialog extends StatefulWidget {
  final String cycleId;

  const ReadinessAlertsDialog({super.key, this.cycleId = '2026-09'});

  @override
  State<ReadinessAlertsDialog> createState() => _ReadinessAlertsDialogState();
}

class _ReadinessAlertsDialogState extends State<ReadinessAlertsDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isBroadcasting = false;
  String? _errorMessage;
  List<NotificationLogRecord> _logs = [];
  String _selectedChannel = 'ALL'; // 'ALL', 'WHATSAPP', 'SMS', 'IVR'
  int _selectedLogIdx = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var res = await _apiService.fetchNotificationLogs(cycleId: widget.cycleId);
      if (res.isEmpty) {
        // Auto dispatch if none exist
        await _apiService.triggerAlertNotifications(cycleId: widget.cycleId);
        res = await _apiService.fetchNotificationLogs(cycleId: widget.cycleId);
      }
      if (mounted) {
        setState(() {
          _logs = res;
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

  Future<void> _triggerBroadcast() async {
    setState(() => _isBroadcasting = true);
    try {
      final res =
          await _apiService.triggerAlertNotifications(cycleId: widget.cycleId);
      final logs =
          await _apiService.fetchNotificationLogs(cycleId: widget.cycleId);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isBroadcasting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.summaryMessage),
            backgroundColor: AppConstants.tealAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBroadcasting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger broadcast: $e'),
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
        width: 1140,
        height: 840,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConstants.tealAccent),
                      SizedBox(height: 12),
                      Text('Loading Pre-Dispatch Alert Telemetry...',
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
                        onPressed: _loadLogs,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              )
            else ...[
              _buildFilterBar(),
              const SizedBox(height: 16),
              Expanded(child: _buildSplitView()),
            ],
            const SizedBox(height: 16),
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
                color: AppConstants.tealAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mark_chat_unread_outlined,
                  color: AppConstants.tealAccent, size: 24),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-Dispatch Readiness & Citizen Alert Dispatcher',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  'Multi-Channel Automated Broadcasts: WhatsApp (FPS Dealers) • SMS & IVR (Beneficiaries)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                  ),
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

  Widget _buildFilterBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildChannelTab('ALL', 'All Alerts (${_logs.length})'),
            const SizedBox(width: 8),
            _buildChannelTab('WHATSAPP', 'WhatsApp (Dealers)'),
            const SizedBox(width: 8),
            _buildChannelTab('SMS', 'SMS (Citizens)'),
            const SizedBox(width: 8),
            _buildChannelTab('IVR', 'IVR Voice'),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _isBroadcasting ? null : _triggerBroadcast,
          icon: _isBroadcasting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 16),
          label: const Text('Re-trigger Multi-Channel Broadcast',
              style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.tealAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildChannelTab(String key, String label) {
    final isSelected = _selectedChannel == key;
    return InkWell(
      onTap: () => setState(() {
        _selectedChannel = key;
        _selectedLogIdx = 0;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.tealAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? AppConstants.tealAccent : AppConstants.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppConstants.textSecondary,
          ),
        ),
      ),
    );
  }

  List<NotificationLogRecord> _getFilteredLogs() {
    if (_selectedChannel == 'ALL') return _logs;
    return _logs.where((l) => l.channel == _selectedChannel).toList();
  }

  Widget _buildSplitView() {
    final items = _getFilteredLogs();
    if (items.isEmpty) {
      return const Center(child: Text('No alerts found for this filter.'));
    }

    final activeLog =
        _selectedLogIdx < items.length ? items[_selectedLogIdx] : items[0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: List of Alert Logs
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final log = items[idx];
                final isSelected = idx == _selectedLogIdx;
                final isDealer = log.recipientType == 'DEALER';

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: AppConstants.tealAccent.withValues(alpha: 0.06),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isDealer
                        ? AppConstants.tealAccent.withValues(alpha: 0.15)
                        : AppConstants.accentBlue.withValues(alpha: 0.15),
                    child: Icon(
                      isDealer ? Icons.store : Icons.person,
                      size: 16,
                      color: isDealer
                          ? AppConstants.tealAccent
                          : AppConstants.accentBlue,
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(log.recipientName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      _buildChannelChip(log.channel),
                    ],
                  ),
                  subtitle: Text(
                    '${log.fpsName} • ${log.recipientPhone}',
                    style: const TextStyle(
                        fontSize: 10, color: AppConstants.textSecondary),
                  ),
                  onTap: () => setState(() => _selectedLogIdx = idx),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Right Column: Live Message Screen Preview
        Expanded(
          flex: 6,
          child: _buildPhoneMessagePreview(activeLog),
        ),
      ],
    );
  }

  Widget _buildChannelChip(String channel) {
    Color c = AppConstants.tealAccent;
    IconData ic = Icons.chat;
    if (channel == 'SMS') {
      c = AppConstants.accentBlue;
      ic = Icons.sms_outlined;
    } else if (channel == 'IVR') {
      c = AppConstants.purpleAccent;
      ic = Icons.phone_in_talk_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 10, color: c),
          const SizedBox(width: 4),
          Text(channel,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }

  Widget _buildPhoneMessagePreview(NotificationLogRecord log) {
    final isWA = log.channel == 'WHATSAPP';

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
          // Device Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isWA
                  ? const Color(0xFF075E54)
                  : AppConstants.primaryNavy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isWA ? Icons.chat : Icons.phone_android,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWA
                          ? 'Govt PDS Dispatch Alert Service (Verified)'
                          : 'Govt PDS SMS Gateway',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Recipient: ${log.recipientName} (${log.recipientPhone})',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Message Bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isWA
                    ? const Color(0xFFDCF8C6).withValues(alpha: 0.6)
                    : AppConstants.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isWA
                        ? const Color(0xFF25D366).withValues(alpha: 0.3)
                        : AppConstants.cardBorder),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.messageTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppConstants.primaryNavy),
                    ),
                    const Divider(height: 12),
                    Text(
                      log.messageBody,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppConstants.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Sent: ${log.sentAt}',
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppConstants.textTertiary)),
                        const SizedBox(width: 6),
                        const Icon(Icons.done_all,
                            size: 14, color: AppConstants.accentBlue),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Telemetry status footer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Delivery Status: ${log.status}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.successGreen)),
                Text(
                    log.acknowledgedAt != null
                        ? '✓ Acknowledged by Dealer'
                        : 'Simulated Delivery Receipt',
                    style: const TextStyle(
                        fontSize: 10, color: AppConstants.textSecondary)),
              ],
            ),
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
          'Notice: DEMO DATA — NOT GOVERNMENT DATA (SIMULATED ALERTS)',
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
