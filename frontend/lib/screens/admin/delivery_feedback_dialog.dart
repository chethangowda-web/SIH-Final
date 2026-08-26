import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class DeliveryFeedbackDialog extends StatefulWidget {
  final String fpsId;
  final String cycleId;

  const DeliveryFeedbackDialog({
    super.key,
    required this.fpsId,
    this.cycleId = '2026-09',
  });

  @override
  State<DeliveryFeedbackDialog> createState() => _DeliveryFeedbackDialogState();
}

class _DeliveryFeedbackDialogState extends State<DeliveryFeedbackDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  late String _selectedFpsId;

  static const List<Map<String, String>> _fpsList = [
    {'id': 'FPS-KA-BLR-001', 'name': '001 - Malleshwaram Seva Kendra'},
    {'id': 'FPS-KA-BLR-002', 'name': '002 - Jayanagar 4th Block Depot'},
    {'id': 'FPS-KA-BLR-003', 'name': '003 - Basavanagudi Grain Center'},
    {'id': 'FPS-KA-BLR-004', 'name': '004 - Rajajinagar 1st Stage FPS'},
    {'id': 'FPS-KA-BLR-005', 'name': '005 - Bellandur Outer Ring Road'},
    {'id': 'FPS-KA-BLR-006', 'name': '006 - Sarjapur Road Extension'},
    {'id': 'FPS-KA-BLR-007', 'name': '007 - Mahadevapura Sub-Center'},
    {'id': 'FPS-KA-BLR-008', 'name': '008 - Thanisandra Main Road'},
    {'id': 'FPS-KA-BLR-009', 'name': '009 - Chickpet Heritage Depot'},
    {'id': 'FPS-KA-BLR-010', 'name': '010 - Shivajinagar Central FPS'},
    {'id': 'FPS-KA-BLR-011', 'name': '011 - Cottonpet Old Ward Kendra'},
    {'id': 'FPS-KA-BLR-012', 'name': '012 - Ulsoor Bazaar Counter'},
    {'id': 'FPS-KA-BLR-013', 'name': '013 - Peenya Industrial Phase-1'},
    {'id': 'FPS-KA-BLR-014', 'name': '014 - Whitefield IT Corridor'},
    {'id': 'FPS-KA-BLR-015', 'name': '015 - Electronic City Phase-2'},
    {'id': 'FPS-KA-BLR-016', 'name': '016 - Bommasandra Industrial'},
    {'id': 'FPS-KA-BLR-017', 'name': '017 - Kengeri Satellite Town'},
    {'id': 'FPS-KA-BLR-018', 'name': '018 - Yelahanka Old Town Depot'},
    {'id': 'FPS-KA-BLR-019', 'name': '019 - Hebbal Distribution Point'},
    {'id': 'FPS-KA-BLR-020', 'name': '020 - Banaswadi Central Depot'},
  ];

  FpsOfftakeFeedbackResult? _feedback;
  final TextEditingController _riceCtrl = TextEditingController(text: '1960');
  final TextEditingController _wheatCtrl = TextEditingController(text: '1090');

  @override
  void initState() {
    super.initState();
    _selectedFpsId = widget.fpsId;
    _loadInitialFeedback();
  }

  @override
  void dispose() {
    _riceCtrl.dispose();
    _wheatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFeedback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.recordActualOfftake(
        fpsId: _selectedFpsId,
        actualRiceKg: double.tryParse(_riceCtrl.text) ?? 1960.0,
        actualWheatKg: double.tryParse(_wheatCtrl.text) ?? 1090.0,
        cycleId: widget.cycleId,
      );
      if (mounted) {
        setState(() {
          _feedback = res;
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

  Future<void> _submitFeedback() async {
    final rice = double.tryParse(_riceCtrl.text.trim());
    final wheat = double.tryParse(_wheatCtrl.text.trim());

    if (rice == null || rice < 0 || wheat == null || wheat < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid non-negative quantities for Rice and Wheat.'),
          backgroundColor: AppConstants.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final res = await _apiService.recordActualOfftake(
        fpsId: _selectedFpsId,
        actualRiceKg: rice,
        actualWheatKg: wheat,
        cycleId: widget.cycleId,
      );
      if (mounted) {
        setState(() {
          _feedback = res;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppConstants.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record feedback: $e'),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 950,
        height: 760,
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
                      Text('Loading Delivery Feedback & Residual Evaluation...',
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
                        onPressed: _loadInitialFeedback,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildBody()),
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
                color: AppConstants.tealAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rate_review_outlined,
                  color: AppConstants.tealAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Delivery Feedback Loop:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFpsId,
                          icon: const Icon(Icons.arrow_drop_down, color: AppConstants.primaryNavy),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryNavy,
                          ),
                          onChanged: (String? newId) {
                            if (newId != null && newId != _selectedFpsId) {
                              setState(() {
                                _selectedFpsId = newId;
                              });
                              _loadInitialFeedback();
                            }
                          },
                          items: _fpsList.map((fps) {
                            return DropdownMenuItem<String>(
                              value: fps['id'],
                              child: Text(fps['name']!),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.tealAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppConstants.tealAccent),
                      ),
                      child: const Text(
                        'CLOSED-LOOP ML',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.tealAccent),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Post-Dispatch Offtake Ingestion → Error Residuals → Closed-Loop Model Calibration',
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

  Widget _buildBody() {
    final fb = _feedback!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Offtake Input Card
          _buildOfftakeInputCard(fb),
          const SizedBox(height: 14),

          // 2. Residual Error & Accuracy Comparison KPI Tiles
          _buildErrorKpiRow(fb),
          const SizedBox(height: 14),

          // 3. Commodity Breakdown Table
          _buildCommodityBreakdownCard(fb),
          const SizedBox(height: 14),

          // 4. Model Feedback & Future Calibration Card
          _buildModelFeedbackCard(fb),
        ],
      ),
    );
  }

  Widget _buildOfftakeInputCard(FpsOfftakeFeedbackResult fb) {
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
              Text(
                'Enter ePoS Actual Offtake (${fb.fpsName})',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
              const Text(
                'Simulate actual lifting to evaluate forecast accuracy',
                style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _riceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Actual Rice Distributed (kg)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.grain, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _wheatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Actual Wheat Distributed (kg)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.bakery_dining_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitFeedback,
                icon: const Icon(Icons.calculate_outlined, size: 16),
                label: const Text('Calculate Residual Error',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorKpiRow(FpsOfftakeFeedbackResult fb) {
    return Row(
      children: [
        _buildKpiCard(
          'PREDICTED FORECAST',
          '${fb.totalForecastQuantityKg.toStringAsFixed(0)} kg',
          'Recommended Quota',
          AppConstants.accentBlue,
          Icons.online_prediction_rounded,
        ),
        _buildKpiCard(
          'ACTUAL OFFTAKE',
          '${fb.totalActualQuantityKg.toStringAsFixed(0)} kg',
          'Biometric ePoS Lifting',
          AppConstants.primaryNavy,
          Icons.shopping_bag_outlined,
        ),
        _buildKpiCard(
          'ABSOLUTE ERROR',
          '${fb.totalAbsoluteErrorKg.toStringAsFixed(0)} kg',
          'MAPE: ${fb.percentageError.toStringAsFixed(2)}%',
          AppConstants.accentAmber,
          Icons.analytics_outlined,
        ),
        _buildKpiCard(
          'ACCURACY INDEX',
          '${fb.overallAccuracyPct.toStringAsFixed(1)}%',
          fb.biasDirection == 'OVER_PREDICTED' ? 'Bias: +Over' : 'Bias: -Under',
          fb.overallAccuracyPct >= 90
              ? AppConstants.successGreen
              : AppConstants.dangerRed,
          Icons.verified_rounded,
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, String subtext, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppConstants.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
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
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: color)),
                  Text(subtext,
                      style: const TextStyle(
                          fontSize: 10, color: AppConstants.textSecondary),
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

  Widget _buildCommodityBreakdownCard(FpsOfftakeFeedbackResult fb) {
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
          const Text(
            'Commodity-Level Residual Performance',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppConstants.primaryNavy),
          ),
          const Divider(height: 16),
          Table(
            border: TableBorder.all(
                color: AppConstants.cardBorder,
                borderRadius: BorderRadius.circular(6)),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(2),
              5: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Commodity',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Forecast',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Actual Offtake',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Abs Error',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('% Error (MAPE)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Accuracy',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
              ),
              ...fb.commodities.map((c) {
                return TableRow(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(c.commodity,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold))),
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${c.forecastQuantityKg.toStringAsFixed(0)} kg',
                            style: const TextStyle(fontSize: 11))),
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${c.actualQuantityKg.toStringAsFixed(0)} kg',
                            style: const TextStyle(fontSize: 11))),
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${c.absoluteErrorKg.toStringAsFixed(0)} kg',
                            style: const TextStyle(fontSize: 11))),
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${c.percentageError.toStringAsFixed(2)}%',
                            style: const TextStyle(fontSize: 11))),
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${c.accuracyPct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.successGreen))),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelFeedbackCard(FpsOfftakeFeedbackResult fb) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.primaryNavy.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppConstants.primaryNavy, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    fb.modelFeedbackStatus,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.successGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  fb.futureCycleReady,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFeedbackBadge(
                  'Dataset State', 'SQLite Training Table Updated', Icons.storage_rounded),
              _buildFeedbackBadge('Sample Growth',
                  fb.trainingSampleCountIncrease, Icons.add_chart_rounded),
              _buildFeedbackBadge(
                  'Ridge Calibration', 'W_recent & W_trend Tuned', Icons.tune_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBadge(String title, String subtitle, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppConstants.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppConstants.primaryNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textSecondary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10,
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

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Notice: DEMO DATA — NOT GOVERNMENT DATA (CLOSED-LOOP EVALUATION)',
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
