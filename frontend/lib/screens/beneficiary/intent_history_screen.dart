import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';

class IntentHistoryScreen extends StatefulWidget {
  final Beneficiary beneficiary;
  final ApiService? apiService;

  const IntentHistoryScreen({
    super.key,
    required this.beneficiary,
    this.apiService,
  });

  @override
  State<IntentHistoryScreen> createState() => _IntentHistoryScreenState();
}

class _IntentHistoryScreenState extends State<IntentHistoryScreen> {
  late final ApiService _apiService;
  List<IntentRecord> _historyRecords = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _apiService.fetchBeneficiaryIntents(
        widget.beneficiary.pseudonymousBeneficiaryId,
      );
      setState(() {
        _historyRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load intent history: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Declared Intent Signal History',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: Colors.white,
              ),
            ),
            Text(
              'PDS DemandSync • Forward-Looking Supply Planning Records',
              style: TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh History',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text('Fetching intent history timeline...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.red.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadHistory,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _historyRecords.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_toggle_off,
                                      size: 56,
                                      color: AppConstants.textSecondary),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Intent Signals Found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppConstants.primaryNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You have not submitted any forward-looking intent declarations for upcoming cycles yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppConstants.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadHistory,
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 20),
                              children: [
                                // Header summary banner
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppConstants.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            AppConstants.primaryNavy,
                                        child: Text(
                                          widget.beneficiary.nameForDemo
                                              .substring(0, 1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.beneficiary.nameForDemo,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppConstants.primaryNavy,
                                              ),
                                            ),
                                            Text(
                                              '${widget.beneficiary.pseudonymousBeneficiaryId} • Registered Home: ${widget.beneficiary.registeredFpsId}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppConstants
                                                    .textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppConstants.accentBlue
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${_historyRecords.length} Signals',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppConstants.accentBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Text(
                                  'CHRONOLOGICAL INTENT SIGNALS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppConstants.textSecondary,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                ..._historyRecords.map((record) {
                                  final isPortability =
                                      record.isPortabilityIntent ||
                                          (record.intendedFpsId !=
                                              widget.beneficiary
                                                  .registeredFpsId);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        side: BorderSide(
                                            color: AppConstants.cardBorder),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      record.commodity == 'Rice'
                                                          ? Icons.grain
                                                          : Icons
                                                              .bakery_dining,
                                                      size: 20,
                                                      color: AppConstants
                                                          .primaryNavy,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${record.commodity} — ${record.declaredQuantityKg.toStringAsFixed(1)} kg',
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppConstants
                                                            .primaryNavy,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.green.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    border: Border.all(
                                                        color: Colors.green
                                                            .shade300),
                                                  ),
                                                  child: Text(
                                                    record.status,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors
                                                          .green.shade800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 20),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'INTENDED TARGET FPS',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AppConstants
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${record.intendedFpsId} — ${record.intendedFpsName ?? "Target FPS"}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isPortability)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants
                                                          .accentAmber
                                                          .withValues(
                                                              alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                          color: AppConstants
                                                              .accentAmber),
                                                    ),
                                                    child: Text(
                                                      'PORTABILITY SHIFT',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppConstants
                                                            .accentAmber,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      'HOME BASE',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors
                                                            .green.shade800,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Allocation Cycle: ${record.cycleId}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppConstants
                                                        .textSecondary,
                                                  ),
                                                ),
                                                Text(
                                                  'Confidence: ${(record.confidence * 100).toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppConstants.accentBlue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),

                                const SizedBox(height: 20),
                                Center(
                                  child: Text(
                                    'DEMO DATA — NOT GOVERNMENT DATA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ),
      ),
    );
  }
}
