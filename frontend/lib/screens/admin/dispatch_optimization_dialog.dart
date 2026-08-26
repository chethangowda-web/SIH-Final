import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class DispatchOptimizationDialog extends StatefulWidget {
  final String cycleId;
  final String? initialTruckId;

  const DispatchOptimizationDialog({
    super.key,
    this.cycleId = '2026-09',
    this.initialTruckId,
  });

  @override
  State<DispatchOptimizationDialog> createState() =>
      _DispatchOptimizationDialogState();
}

class _DispatchOptimizationDialogState
    extends State<DispatchOptimizationDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isRecalculating = false;
  String? _errorMessage;

  CorridorOptimizationDossier? _dossier;
  String _selectedTruckId = 'DEMO-KA-04-E-1021';

  // What-If Parameters
  double _vehicleCapacityKg = 10000.0;
  double _fuelCostPerKm = 32.0;
  String _routeCondition = 'URBAN_ARTERIAL';
  String _departureWindow = '08:30 AM';

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
    _loadOptimization();
  }

  Future<void> _loadOptimization({String? truckId}) async {
    final tid = truckId ?? _selectedTruckId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedTruckId = tid;
    });

    try {
      final res = await _apiService.fetchCorridorOptimization(
        tid,
        cycleId: widget.cycleId,
      );
      if (mounted) {
        setState(() {
          _dossier = res;
          _vehicleCapacityKg = res.evaluatedCandidates.isNotEmpty
              ? res.evaluatedCandidates.first.vehicleCapacityKg
              : 10000.0;
          _fuelCostPerKm = res.fuelCostPerKm;
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

  Future<void> _runWhatIfRecalculation() async {
    setState(() => _isRecalculating = true);

    try {
      final res = await _apiService.simulateWhatIfOptimization(
        truckId: _selectedTruckId,
        vehicleCapacityKg: _vehicleCapacityKg,
        fuelCostPerKm: _fuelCostPerKm,
        routeCondition: _routeCondition,
        departureWindow: _departureWindow,
        cycleId: widget.cycleId,
      );
      if (mounted) {
        setState(() {
          _dossier = res;
          _isRecalculating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Optimization updated: Optimal candidate is ${res.selectedCandidateId} (Score: ${res.selectedOptimizationScore})'),
            backgroundColor: AppConstants.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRecalculating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('What-if calculation failed: $e'),
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
                      Text(
                          'Evaluating Multi-Candidate TSP Routes & Penalty Scores...',
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
                        onPressed: () => _loadOptimization(),
                        child: const Text('Retry Optimization'),
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
              child: const Icon(Icons.route_rounded,
                  color: AppConstants.purpleAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Multi-Candidate Dispatch Optimization Engine',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  'Minimize Transport Cost + Stock-out Risk + Delay Penalty • TSP Tour Sequencing',
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

  Widget _buildScrollableBody() {
    final d = _dossier!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Corridor Selector Bar
          _buildCorridorSelectorBar(),
          const SizedBox(height: 14),

          // 2. Interactive What-If Scenario Controls
          _buildWhatIfControlsCard(),
          const SizedBox(height: 14),

          // 3. Multi-Candidate Comparative Grid (Candidate A, B, C)
          _buildCandidateComparisonSection(d),
          const SizedBox(height: 14),

          // 4. "Why this candidate was selected?" Justification Card
          _buildWhySelectedJustificationCard(d),
          const SizedBox(height: 14),

          // 5. Optimized Delivery Sequence Timeline (TSP Nearest-Neighbor Tour)
          _buildDeliverySequenceSection(d),
        ],
      ),
    );
  }

  Widget _buildCorridorSelectorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route_rounded,
                  color: AppConstants.primaryNavy, size: 18),
              SizedBox(width: 8),
              Text(
                'FLEET CORRIDOR:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textSecondary),
              ),
            ],
          ),
          Row(
            children: _corridors.map((c) {
              final isSelected = c['truck_id'] == _selectedTruckId;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ElevatedButton(
                  onPressed: () => _loadOptimization(truckId: c['truck_id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? AppConstants.primaryNavy
                        : Colors.grey.shade200,
                    foregroundColor:
                        isSelected ? Colors.white : AppConstants.textPrimary,
                    elevation: isSelected ? 2 : 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
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

  Widget _buildWhatIfControlsCard() {
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
              const Row(
                children: [
                  Icon(Icons.tune_rounded,
                      color: AppConstants.purpleAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Interactive What-If Scenario Controls',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isRecalculating ? null : _runWhatIfRecalculation,
                icon: _isRecalculating
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.calculate_outlined, size: 14),
                label: const Text('Recalculate Optimization',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.purpleAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Vehicle Capacity Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Vehicle Capacity Rating',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        Text('${(_vehicleCapacityKg / 1000).toStringAsFixed(1)} MT',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primaryNavy)),
                      ],
                    ),
                    Slider(
                      value: _vehicleCapacityKg.clamp(3000.0, 16000.0),
                      min: 3000.0,
                      max: 16000.0,
                      divisions: 13,
                      activeColor: AppConstants.accentBlue,
                      onChanged: (val) =>
                          setState(() => _vehicleCapacityKg = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 2. Fuel Cost per KM Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Operating / Fuel Cost Rate',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        Text('₹${_fuelCostPerKm.toStringAsFixed(1)} / km',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primaryNavy)),
                      ],
                    ),
                    Slider(
                      value: _fuelCostPerKm.clamp(20.0, 70.0),
                      min: 20.0,
                      max: 70.0,
                      divisions: 10,
                      activeColor: AppConstants.successGreen,
                      onChanged: (val) => setState(() => _fuelCostPerKm = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 3. Route Condition Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Route Corridor Condition',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _routeCondition,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'EXPRESSWAY_CORRIDOR',
                            child: Text('Expressway / Ring Road',
                                style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(
                            value: 'URBAN_ARTERIAL',
                            child: Text('Standard Urban Arterial',
                                style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(
                            value: 'CONGESTED_PEAK_CORRIDOR',
                            child: Text('Congested Core (Peak Delay)',
                                style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _routeCondition = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 4. Departure Window Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dispatch Departure Window',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _departureWindow,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: '07:30 AM',
                            child: Text('07:30 AM (Early Priority)',
                                style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(
                            value: '08:30 AM',
                            child: Text('08:30 AM (Standard Morning)',
                                style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(
                            value: '09:15 AM',
                            child: Text('09:15 AM (Mid-Morning Slot)',
                                style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _departureWindow = val);
                      },
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

  Widget _buildCandidateComparisonSection(CorridorOptimizationDossier d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.compare_rounded,
                color: AppConstants.primaryNavy, size: 18),
            SizedBox(width: 8),
            Text(
              'Multi-Candidate Feasibility & Penalty Scoring Comparison',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryNavy),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: d.evaluatedCandidates.map((c) {
            return Expanded(
              child: _buildCandidateCard(c),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCandidateCard(OptimizationCandidate c) {
    final isSelected = c.isSelected;
    final b = c.scoreBreakdown;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? AppConstants.successGreen.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppConstants.successGreen
              : AppConstants.cardBorder,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                    color: AppConstants.successGreen.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppConstants.successGreen
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  c.candidateId,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppConstants.textPrimary),
                ),
              ),
              if (isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppConstants.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('✓ OPTIMAL',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppConstants.successGreen)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.candidateName,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryNavy),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            '${c.truckModel} • Dep: ${c.departureWindow}',
            style: const TextStyle(
                fontSize: 10, color: AppConstants.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 14),
          // Total Penalty Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Composite Penalty Score (Φ):',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text(
                c.compositePenaltyScore.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? AppConstants.successGreen
                        : AppConstants.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Score Breakdown bars
          _buildScoreBar('Transport Cost Score', b.transportCostScore, 8.0,
              AppConstants.accentBlue),
          _buildScoreBar('Stockout Risk Penalty', b.stockoutRiskPenalty, 8.0,
              AppConstants.purpleAccent),
          _buildScoreBar('Excess Stock Penalty', b.excessStockPenalty, 8.0,
              AppConstants.accentAmber),
          _buildScoreBar(
              'Transit Delay Penalty', b.delayPenalty, 8.0, AppConstants.dangerRed),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Distance: ${c.totalDistanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                      fontSize: 10, color: AppConstants.textSecondary)),
              Text('Est. Cost: ₹${c.estimatedTransportCostInr.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryNavy)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Duration: ${c.estimatedDurationMins} mins',
                  style: const TextStyle(
                      fontSize: 10, color: AppConstants.textSecondary)),
              Text('Efficiency: ${c.optimizationEfficiencyPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppConstants.successGreen
                          : AppConstants.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(
      String label, double value, double maxVal, Color color) {
    final pct = (value / maxVal).clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 8, color: AppConstants.textSecondary)),
              Text(value.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhySelectedJustificationCard(CorridorOptimizationDossier d) {
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
              Icon(Icons.verified_rounded,
                  color: AppConstants.successGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Optimization Decision Justification',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d.whySelectedReason,
            style: const TextStyle(
                fontSize: 12,
                color: AppConstants.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySequenceSection(CorridorOptimizationDossier d) {
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
                  const Icon(Icons.format_list_numbered_rounded,
                      color: AppConstants.accentBlue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Optimized TSP Delivery Sequence (${d.deliverySequence.length} Shop Stops)',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Text(
                'Source: ${d.sourceDepot}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textSecondary),
              ),
            ],
          ),
          const Divider(height: 16),
          ...d.deliverySequence.map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppConstants.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryNavy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${s.sequenceOrder}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fpsName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textPrimary)),
                        Text('${s.fpsId} • ${s.district}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppConstants.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ETA: ${s.estimatedArrivalWindow}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.accentBlue)),
                        Text(
                            'Leg: ${s.legDistanceKm} km (Cum: ${s.cumulativeDistanceKm} km)',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppConstants.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Drop: ${s.totalDropKg.toStringAsFixed(0)} kg',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.successGreen)),
                        Text(
                            'Rice: ${s.riceKg.toStringAsFixed(0)}kg • Wheat: ${s.wheatKg.toStringAsFixed(0)}kg',
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppConstants.textSecondary)),
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
          'Notice: DEMO DATA — NOT GOVERNMENT DATA (DISPATCH OPTIMIZATION ENGINE)',
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
