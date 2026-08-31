import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _isRecalculating = false;
  String? _errorMessage;

  CorridorOptimizationDossier? _dossier;
  String _selectedTruckId = 'DEMO-KA-04-E-1021';
  OptimizedStop? _selectedMapStop;
  bool _isDepotSelected = false;

  // Live Dispatch Simulation State
  bool _isSimulationRunning = false;
  bool _isSimulationPaused = false;
  int _simulationCurrentStopIdx = 0;
  double _simulationStepFraction = 0.0;
  bool _isCorridorBreachSimulated = false;
  Timer? _simulationTimer;
  LatLng? _simulatedTruckPosition;
  String _simulatedTruckStatus = 'AT_DEPOT';
  double _simulatedRemainingPayloadKg = 10000.0;

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

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startSimulation() {
    if (_dossier == null) return;
    final points = _buildRoutePoints(_dossier!);
    if (points.length < 2) return;

    _simulationTimer?.cancel();
    setState(() {
      _isSimulationRunning = true;
      _isSimulationPaused = false;
      _simulationCurrentStopIdx = 0;
      _simulationStepFraction = 0.0;
      _isCorridorBreachSimulated = false;
      _simulatedTruckPosition = points[0];
      _simulatedTruckStatus = 'DEPARTED_DEPOT';
      _simulatedRemainingPayloadKg = _dossier!.totalCorridorDemandKg;
    });

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isSimulationPaused) return;

      final currentPoints = _buildRoutePoints(_dossier!);
      if (_simulationCurrentStopIdx >= currentPoints.length - 1) {
        setState(() {
          _simulatedTruckPosition = currentPoints.last;
          _simulatedTruckStatus = 'TOUR_COMPLETED_RETURNED_TO_DEPOT';
          _isSimulationRunning = false;
        });
        timer.cancel();
        return;
      }

      setState(() {
        _simulationStepFraction += 0.34;
        if (_simulationStepFraction >= 1.0) {
          _simulationStepFraction = 0.0;
          _simulationCurrentStopIdx++;

          if (_simulationCurrentStopIdx < _dossier!.deliverySequence.length + 1 && _simulationCurrentStopIdx > 0) {
            final stop = _dossier!.deliverySequence[_simulationCurrentStopIdx - 1];
            _simulatedTruckStatus = 'ARRIVED & OFFLOADING: ${stop.fpsName}';
            final dropped = stop.totalDropKg > 0 ? stop.totalDropKg : (stop.riceKg + stop.wheatKg);
            _simulatedRemainingPayloadKg = (_simulatedRemainingPayloadKg - dropped).clamp(0.0, 50000.0);
          } else if (_simulationCurrentStopIdx >= currentPoints.length - 1) {
            _simulatedTruckStatus = 'TOUR_COMPLETED_RETURNED_TO_DEPOT';
            _isSimulationRunning = false;
            timer.cancel();
          }
        }

        if (_simulationCurrentStopIdx < currentPoints.length - 1) {
          final p1 = currentPoints[_simulationCurrentStopIdx];
          final p2 = currentPoints[_simulationCurrentStopIdx + 1];
          final interpLat = p1.latitude + (p2.latitude - p1.latitude) * _simulationStepFraction;
          final interpLng = p1.longitude + (p2.longitude - p1.longitude) * _simulationStepFraction;

          if (_isCorridorBreachSimulated) {
            _simulatedTruckPosition = LatLng(interpLat + 0.015, interpLng + 0.012);
            _simulatedTruckStatus = 'CORRIDOR_GEOFENCE_BREACH_ALERT';
          } else {
            _simulatedTruckPosition = LatLng(interpLat, interpLng);
            if (!_simulatedTruckStatus.contains('ARRIVED')) {
              _simulatedTruckStatus = 'EN_ROUTE_TO_NEXT_FPS';
            }
          }
        }
      });
    });
  }

  void _pauseSimulation() {
    setState(() {
      _isSimulationPaused = !_isSimulationPaused;
    });
  }

  void _stepNextStop() {
    if (_dossier == null) return;
    final points = _buildRoutePoints(_dossier!);
    setState(() {
      _isSimulationRunning = true;
      if (_simulationCurrentStopIdx < points.length - 1) {
        _simulationCurrentStopIdx++;
        _simulationStepFraction = 0.0;
        _simulatedTruckPosition = points[_simulationCurrentStopIdx];

        if (_simulationCurrentStopIdx <= _dossier!.deliverySequence.length && _simulationCurrentStopIdx > 0) {
          final stop = _dossier!.deliverySequence[_simulationCurrentStopIdx - 1];
          _simulatedTruckStatus = 'ARRIVED & OFFLOADING: ${stop.fpsName}';
          final dropped = stop.totalDropKg > 0 ? stop.totalDropKg : (stop.riceKg + stop.wheatKg);
          _simulatedRemainingPayloadKg = (_simulatedRemainingPayloadKg - dropped).clamp(0.0, 50000.0);
        } else {
          _simulatedTruckStatus = 'TOUR_COMPLETED_RETURNED_TO_DEPOT';
        }
      }
    });
  }

  void _toggleCorridorDeviationAlert() {
    setState(() {
      _isCorridorBreachSimulated = !_isCorridorBreachSimulated;
      if (_isCorridorBreachSimulated && _simulatedTruckPosition != null) {
        _simulatedTruckPosition = LatLng(
          _simulatedTruckPosition!.latitude + 0.015,
          _simulatedTruckPosition!.longitude + 0.012,
        );
        _simulatedTruckStatus = 'CORRIDOR_GEOFENCE_BREACH_ALERT';
      }
    });
  }

  void _resetSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulationRunning = false;
      _isSimulationPaused = false;
      _simulationCurrentStopIdx = 0;
      _simulationStepFraction = 0.0;
      _isCorridorBreachSimulated = false;
      _simulatedTruckPosition = null;
      _simulatedTruckStatus = 'AT_DEPOT';
      if (_dossier != null) {
        _simulatedRemainingPayloadKg = _dossier!.totalCorridorDemandKg;
      }
    });
  }

  Future<void> _loadOptimization({String? truckId}) async {
    final tid = truckId ?? _selectedTruckId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedTruckId = tid;
      _selectedMapStop = null;
      _isDepotSelected = false;
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
          _selectedMapStop = null;
          _isDepotSelected = false;
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
          _selectedMapStop = null;
          _isDepotSelected = false;
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

          // 5. Interactive Delivery Corridor Map (OpenStreetMap)
          _buildInteractiveRouteMapSection(d),
          const SizedBox(height: 14),

          // 6. Optimized Delivery Sequence Timeline (TSP Nearest-Neighbor Tour)
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

  LatLng _getDepotLatLng(CorridorOptimizationDossier d) {
    if (d.sourceDepot.toLowerCase().contains('banaswadi') ||
        d.sourceDepot.contains('DEPOT-02')) {
      return const LatLng(13.0100, 77.6500);
    }
    return const LatLng(13.0358, 77.5970); // Bengaluru Central FCI Godown (Hebbal)
  }

  List<LatLng> _buildRoutePoints(CorridorOptimizationDossier d) {
    final depot = _getDepotLatLng(d);
    final points = <LatLng>[depot];
    for (final stop in d.deliverySequence) {
      if (stop.latitude != 0.0 && stop.longitude != 0.0) {
        points.add(LatLng(stop.latitude, stop.longitude));
      }
    }
    points.add(depot); // Return loop to depot
    return points;
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(12.9716, 77.5946);
    double sumLat = 0;
    double sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  Widget _buildInteractiveRouteMapSection(CorridorOptimizationDossier d) {
    final routePoints = _buildRoutePoints(d);
    final center = _calculateCenter(routePoints);
    final depotPoint = _getDepotLatLng(d);

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
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.map_rounded,
                        color: AppConstants.primaryNavy, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INTERACTIVE DELIVERY CORRIDOR MAP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryNavy,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'OpenStreetMap • Backend-optimized TSP sequence',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Header right summary pills
              Wrap(
                spacing: 8,
                children: [
                  _buildMapMetricChip(
                    icon: Icons.storefront_rounded,
                    label: '${d.deliverySequence.length} FPS Stops',
                    color: AppConstants.accentBlue,
                  ),
                  _buildMapMetricChip(
                    icon: Icons.timeline_rounded,
                    label: '${d.selectedRouteDistanceKm.toStringAsFixed(1)} km Tour',
                    color: AppConstants.purpleAccent,
                  ),
                  _buildMapMetricChip(
                    icon: Icons.speed_rounded,
                    label: '${d.selectedEfficiencyPct.toStringAsFixed(1)}% Efficiency',
                    color: AppConstants.successGreen,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Simulation Control Toolbar & Live Telemetry Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.satellite_alt_rounded, size: 16, color: AppConstants.primaryNavy),
                const SizedBox(width: 8),
                const Text(
                  'Live Dispatch Simulation & Corridor Guard:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSimulationRunning
                      ? (_isSimulationPaused ? _pauseSimulation : _pauseSimulation)
                      : _startSimulation,
                  icon: Icon(
                    _isSimulationRunning
                        ? (_isSimulationPaused ? Icons.play_arrow : Icons.pause)
                        : Icons.play_arrow,
                    size: 14,
                  ),
                  label: Text(
                    _isSimulationRunning
                        ? (_isSimulationPaused ? 'Resume' : 'Pause')
                        : 'Start Dispatch Simulation',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSimulationRunning
                        ? (_isSimulationPaused ? Colors.green : Colors.amber.shade800)
                        : AppConstants.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _stepNextStop,
                  icon: const Icon(Icons.skip_next, size: 14),
                  label: const Text('Next Stop', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _toggleCorridorDeviationAlert,
                  icon: const Icon(Icons.warning_amber_rounded, size: 14),
                  label: Text(
                    _isCorridorBreachSimulated ? 'Clear Deviation Alert' : 'Simulate Route Deviation (Alert)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCorridorBreachSimulated ? Colors.red.shade700 : Colors.deepOrange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 18),
                  tooltip: 'Reset Simulation',
                  onPressed: _resetSimulation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // High-Priority Corridor Deviation Banner (when triggered)
          if (_isCorridorBreachSimulated) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade400, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ GEOFENCE BREACH DETECTED: Carrier $_selectedTruckId deviated 1.6 km from authorized NFSA transit corridor! High-priority telemetry alert dispatched to District Supply Officer & Central Enforcement.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Interactive Map Container
          Container(
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 12.0,
                      minZoom: 8.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'org.karnataka.pds_demandsync',
                        errorTileCallback: (tile, error, stackTrace) {
                          // Gracefully handle tile loading error without breaking dialog
                        },
                      ),
                      // Route Polylines
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 4.5,
                            color: AppConstants.primaryNavy,
                            borderStrokeWidth: 2.0,
                            borderColor: Colors.white,
                          ),
                          if (_isCorridorBreachSimulated && _simulatedTruckPosition != null)
                            Polyline(
                              points: [
                                routePoints[_simulationCurrentStopIdx.clamp(0, routePoints.length - 1)],
                                _simulatedTruckPosition!,
                              ],
                              strokeWidth: 3.0,
                              color: Colors.red,
                              pattern: StrokePattern.dashed(segments: const [6, 4]),
                            ),
                        ],
                      ),
                      // Markers (Depot + Numbered Stops + Live Truck)
                      MarkerLayer(
                        markers: [
                          // 1. Depot Origin Marker
                          Marker(
                            point: depotPoint,
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isDepotSelected = true;
                                  _selectedMapStop = null;
                                });
                              },
                              child: Tooltip(
                                message: 'Origin Depot: ${d.sourceDepot}',
                                child: _buildDepotMarkerWidget(),
                              ),
                            ),
                          ),
                          // 2. FPS Destination Markers
                          ...d.deliverySequence.map((stop) {
                            final isSel = _selectedMapStop?.fpsId == stop.fpsId;
                            return Marker(
                              point: LatLng(stop.latitude, stop.longitude),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMapStop = stop;
                                    _isDepotSelected = false;
                                  });
                                },
                                child: Tooltip(
                                  message: 'Stop ${stop.sequenceOrder}: ${stop.fpsName} (${stop.fpsId})',
                                  child: _buildStopMarkerWidget(stop, isSel),
                                ),
                              ),
                            );
                          }),
                          // 3. Live Simulated Truck Marker
                          if (_simulatedTruckPosition != null)
                            Marker(
                              point: _simulatedTruckPosition!,
                              width: 60,
                              height: 60,
                              child: _buildSimulatedTruckMarkerWidget(),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Floating Legend & Map Controls (Top Right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            tooltip: 'Zoom In',
                            onPressed: () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1.0,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            tooltip: 'Zoom Out',
                            onPressed: () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1.0,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                            tooltip: 'Fit Corridor View',
                            onPressed: () {
                              _mapController.move(center, 12.0);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // OpenStreetMap Attribution (Top Left)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Floating Marker Info Card (Bottom Overlay)
                  if (_selectedMapStop != null || _isDepotSelected)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _buildMapInfoPopup(d),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLiveTelemetryCard(d),
        ],
      ),
    );
  }

  Widget _buildSimulatedTruckMarkerWidget() {
    final isBreach = _isCorridorBreachSimulated;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isBreach ? Colors.red.shade800 : AppConstants.primaryNavy,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: (isBreach ? Colors.red : Colors.blue).withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(
            isBreach ? 'BREACH' : 'TRUCK',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isBreach ? Colors.red : const Color(0xFF0284C7),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTelemetryCard(CorridorOptimizationDossier d) {
    final nextStop = (_simulationCurrentStopIdx < d.deliverySequence.length)
        ? d.deliverySequence[_simulationCurrentStopIdx]
        : null;

    final isBreach = _isCorridorBreachSimulated;
    final cleanTruckId = _selectedTruckId.replaceAll('DEMO-', '');
    const driver = 'Ramesh Kumar (Designated Driver)';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBreach ? Colors.red.shade50 : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isBreach ? Colors.red.shade400 : Colors.blueGrey.shade200, width: isBreach ? 1.5 : 1.0),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Truck Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isBreach ? Colors.red.shade700 : AppConstants.primaryNavy,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(isBreach ? Icons.fmd_bad_rounded : Icons.satellite_alt_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _simulatedTruckStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Geofence Corridor Guard Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBreach ? Colors.red.shade100 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isBreach ? Colors.red : Colors.green.shade400),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBreach ? Icons.warning_amber_rounded : Icons.shield_rounded,
                      size: 12,
                      color: isBreach ? Colors.red.shade900 : Colors.green.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBreach ? 'GEOFENCE BREACH (>1.5 km)' : 'AUTHORIZED CORRIDOR LOCKED',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isBreach ? Colors.red.shade900 : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Synthetic Telemetry Notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Simulated Telemetry Stream (1.0 Hz)',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Secondary Telemetry Row: Coordinates, Vehicle, Payload, Stops
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carrier: $cleanTruckId • Driver: $driver',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'GPS Telemetry: ${_simulatedTruckPosition != null ? "${_simulatedTruckPosition!.latitude.toStringAsFixed(4)}°N, ${_simulatedTruckPosition!.longitude.toStringAsFixed(4)}°E" : "Depot Base Standby"}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextStop != null
                          ? 'Next Stop ${_simulationCurrentStopIdx + 1}: ${nextStop.fpsName}'
                          : 'Tour Status: Central Godown Complete',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextStop != null
                          ? 'Leg Distance: ${nextStop.legDistanceKm.toStringAsFixed(1)} km • Time Window: ${nextStop.estimatedArrivalWindow.isNotEmpty ? nextStop.estimatedArrivalWindow : "08:30-09:30 AM"}'
                          : 'All scheduled fair-price deliveries completed.',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Cargo Onboard: ${_simulatedRemainingPayloadKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
                    ),
                    Text(
                      'Progress: ${_simulationCurrentStopIdx.clamp(0, d.deliverySequence.length)} of ${d.deliverySequence.length} FPS Delivered',
                      style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
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

  Widget _buildDepotMarkerWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppConstants.dangerRed,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 3,
              ),
            ],
          ),
          child: const Text(
            'DEPOT',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const Icon(
          Icons.warehouse_rounded,
          color: AppConstants.dangerRed,
          size: 26,
        ),
      ],
    );
  }

  Widget _buildStopMarkerWidget(OptimizedStop stop, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.successGreen : AppConstants.primaryNavy,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? AppConstants.successGreen : AppConstants.primaryNavy)
                    .withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            '${stop.sequenceOrder}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Icon(
          Icons.arrow_drop_down,
          size: 14,
          color: isSelected ? AppConstants.successGreen : AppConstants.primaryNavy,
        ),
      ],
    );
  }

  Widget _buildMapMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapInfoPopup(CorridorOptimizationDossier d) {
    if (_isDepotSelected) {
      final depotLatLng = _getDepotLatLng(d);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppConstants.dangerRed.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.dangerRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.warehouse_rounded, color: AppConstants.dangerRed, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Origin Warehouse / FCI Buffer Godown',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppConstants.dangerRed)),
                  Text(d.sourceDepot,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  Text('GPS: ${depotLatLng.latitude.toStringAsFixed(4)}° N, ${depotLatLng.longitude.toStringAsFixed(4)}° E • Loading Bay-01/02',
                      style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _isDepotSelected = false),
            ),
          ],
        ),
      );
    }

    final s = _selectedMapStop!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppConstants.primaryNavy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${s.sequenceOrder}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Stop ${s.sequenceOrder}: ${s.fpsName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                    const SizedBox(width: 6),
                    Text('(${s.fpsId})',
                        style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Drop: ${s.totalDropKg.toStringAsFixed(0)} kg (Rice: ${s.riceKg.toStringAsFixed(0)}kg, Wheat: ${s.wheatKg.toStringAsFixed(0)}kg) • Leg: ${s.legDistanceKm} km (Cumulative: ${s.cumulativeDistanceKm} km) • ETA: ${s.estimatedArrivalWindow}',
                  style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _selectedMapStop = null),
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
