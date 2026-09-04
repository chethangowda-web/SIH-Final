import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
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
      if (mounted) {
        setState(() {
          _historyRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load intent history: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppConstants.bgLight,
          appBar: AppBar(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 16,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('history.title'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${tr('app.name')} • ${tr('app.cycle_label')}',
                  style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LanguageSelectorWidget(isCompact: true),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: tr('nav.refresh'),
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadHistory,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(strokeWidth: 3),
                            const SizedBox(height: 16),
                            Text(tr('profile.loading')),
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
                                    label: Text(tr('profile.error_retry')),
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
                                      const Icon(Icons.history_toggle_off,
                                          size: 56,
                                          color: AppConstants.textSecondary),
                                      const SizedBox(height: 16),
                                      Text(
                                        tr('history.title'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppConstants.primaryNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        tr('history.empty'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
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
                                                  style: const TextStyle(
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
                                      tr('history.timeline_header').toUpperCase(),
                                      style: const TextStyle(
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
                                      final commName = record.commodity.toLowerCase() == 'rice'
                                          ? tr('commodity.rice')
                                          : tr('commodity.wheat');

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Card(
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: const BorderSide(
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
                                                          '$commName — ${record.declaredQuantityKg.toStringAsFixed(1)} ${tr('commodity.kg')}',
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
                                                            style: const TextStyle(
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
                                                          tr('intent.portability_tag'),
                                                          style: const TextStyle(
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
                                                          tr('intent.home_fps_tag'),
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
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppConstants
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Confidence: ${(record.confidence * 100).toStringAsFixed(0)}%',
                                                      style: const TextStyle(
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
                                        tr('app.gov_badge'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
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
      },
    );
  }
}
