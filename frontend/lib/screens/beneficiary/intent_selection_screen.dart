import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import 'intent_confirmation_screen.dart';

class IntentSelectionScreen extends StatefulWidget {
  final Beneficiary beneficiary;
  final ApiService? apiService;

  const IntentSelectionScreen({
    super.key,
    required this.beneficiary,
    this.apiService,
  });

  @override
  State<IntentSelectionScreen> createState() => _IntentSelectionScreenState();
}

class _IntentSelectionScreenState extends State<IntentSelectionScreen> {
  late final ApiService _apiService;
  List<FpsShop> _fpsList = [];
  FpsShop? _selectedFps;
  String _selectedCommodityOption = 'Both'; // 'Rice', 'Wheat', 'Both'
  double _riceQuantityKg = 25.0;
  double _wheatQuantityKg = 10.0;
  bool _isLoadingFps = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isChoiceWindowOpen = true;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadFpsList();
  }

  Future<void> _loadFpsList() async {
    setState(() {
      _isLoadingFps = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.fetchFpsList();
      bool isOpen = true;
      try {
        final win = await _apiService.fetchChoiceWindowStatus(cycleId: '2026-09');
        isOpen = win['is_open'] ?? true;
      } catch (_) {}

      setState(() {
        _fpsList = list;
        _isChoiceWindowOpen = isOpen;
        // Default to registered FPS if available, else first FPS
        _selectedFps = _fpsList.firstWhere(
          (fps) => fps.fpsId == widget.beneficiary.registeredFpsId,
          orElse: () => _fpsList.first,
        );
        _isLoadingFps = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load Fair Price Shops: $e';
        _isLoadingFps = false;
      });
    }
  }

  // Calculate simulated distance in km based on coordinates or relative index
  double _getCalculatedDistance(FpsShop fps) {
    if (fps.fpsId == widget.beneficiary.registeredFpsId) {
      return 0.4; // Home shop is walking distance
    }
    // Pseudo-distance based on lat/lng coordinate delta for demonstration
    final dLat = (fps.latitude - 12.9716).abs() * 111.0;
    final dLng = (fps.longitude - 77.5946).abs() * 105.0;
    final dist = sqrt(dLat * dLat + dLng * dLng) + 1.2;
    return double.parse(dist.toStringAsFixed(1));
  }

  Future<void> _submitIntent() async {
    if (_selectedFps == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final results = await _apiService.submitIntent(
        beneficiaryId: widget.beneficiary.pseudonymousBeneficiaryId,
        intendedFpsId: _selectedFps!.fpsId,
        commodityOption: _selectedCommodityOption,
        riceQuantityKg: _riceQuantityKg,
        wheatQuantityKg: _wheatQuantityKg,
        cycleId: '2026-09',
        confidence: 0.95,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      // Navigate to Confirmation Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => IntentConfirmationScreen(
            beneficiary: widget.beneficiary,
            intendedFps: _selectedFps!,
            commodityOption: _selectedCommodityOption,
            submittedRecords: results,
            apiService: _apiService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Error submitting intent: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHomeFps =
        _selectedFps?.fpsId == widget.beneficiary.registeredFpsId;

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      appBar: AppBar(
        title: const Text(
          'Select Intended FPS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoadingFps
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Loading available Fair Price Shops...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Prompt
                      const Text(
                        'Where do you intend to collect your ration next cycle?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppConstants.primaryNavy,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select where you plan to pick up your ration for Cycle 7 (September 2026). You can choose your home shop or any other shop across the city.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppConstants.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Choice Window Status Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isChoiceWindowOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isChoiceWindowOpen ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isChoiceWindowOpen ? Icons.timelapse : Icons.lock_clock,
                              color: _isChoiceWindowOpen ? AppConstants.successGreen : Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isChoiceWindowOpen
                                        ? 'CHOICE WINDOW: OPEN (Cycle 2026-09)'
                                        : 'CHOICE WINDOW: CLOSED — DEMAND LOCKED',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _isChoiceWindowOpen ? const Color(0xFF065F46) : Colors.red.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isChoiceWindowOpen
                                        ? 'Portability preferences are currently being accepted. Window closes prior to godown dispatch planning.'
                                        : 'Choice window for this cycle has closed. Demand baseline is frozen and locked into godown dispatch optimization.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _isChoiceWindowOpen ? const Color(0xFF047857) : Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 1: Fair Price Shop Options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SELECT FAIR PRICE SHOP (${_fpsList.length} AVAILABLE)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.textSecondary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      ..._fpsList.map((fps) {
                        final isSelected = _selectedFps?.fpsId == fps.fpsId;
                        final isRegisteredHome =
                            fps.fpsId == widget.beneficiary.registeredFpsId;
                        final distance = _getCalculatedDistance(fps);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedFps = fps;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppConstants.accentBlue
                                        .withValues(alpha: 0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppConstants.accentBlue
                                      : AppConstants.cardBorder,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppConstants.accentBlue
                                              .withValues(alpha: 0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppConstants.accentBlue
                                            : Colors.grey.shade400,
                                        width: isSelected ? 6.5 : 2.0,
                                      ),
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                fps.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: isSelected
                                                      ? AppConstants.primaryNavy
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (isRegisteredHome)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                      color: Colors
                                                          .green.shade300),
                                                ),
                                                child: Text(
                                                  'CURRENT HOME FPS',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        Colors.green.shade800,
                                                  ),
                                                ),
                                              )
                                            else
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppConstants.accentAmber
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'PORTABILITY NODE',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppConstants.accentAmber,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              fps.fpsId,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const Text(' • ',
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                            Icon(Icons.location_on_outlined,
                                                size: 13,
                                                color:
                                                    AppConstants.textSecondary),
                                            const SizedBox(width: 2),
                                            Text(
                                              '$distance km away',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppConstants.textSecondary,
                                              ),
                                            ),
                                            const Text(' • ',
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                            Text(
                                              'Cap: ${(fps.capacityKg / 1000).toStringAsFixed(0)} Ton',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppConstants.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // Section 2: Commodity Selection
                      Text(
                        'COMMODITY SELECTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _buildCommodityChoiceChip(
                              'Both (Rice & Wheat)',
                              'Both',
                              Icons.all_inclusive,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCommodityChoiceChip(
                              'Rice Only',
                              'Rice',
                              Icons.grain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCommodityChoiceChip(
                              'Wheat Only',
                              'Wheat',
                              Icons.bakery_dining,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Section 3: Quantity Adjusters
                      Text(
                        'DECLARED PLANNING QUANTITY (KG)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_selectedCommodityOption == 'Rice' ||
                          _selectedCommodityOption == 'Both')
                        _buildQuantitySlider(
                          label: 'Rice Quota (kg)',
                          value: _riceQuantityKg,
                          min: 5.0,
                          max: 35.0,
                          icon: Icons.grain,
                          color: AppConstants.primaryNavy,
                          onChanged: (val) {
                            setState(() {
                              _riceQuantityKg = val;
                            });
                          },
                        ),

                      if (_selectedCommodityOption == 'Wheat' ||
                          _selectedCommodityOption == 'Both') ...[
                        const SizedBox(height: 10),
                        _buildQuantitySlider(
                          label: 'Wheat Quota (kg)',
                          value: _wheatQuantityKg,
                          min: 5.0,
                          max: 15.0,
                          icon: Icons.bakery_dining,
                          color: AppConstants.accentAmber,
                          onChanged: (val) {
                            setState(() {
                              _wheatQuantityKg = val;
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // IMPORTANT DISCLAIMER CALLOUT
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppConstants.accentAmber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                AppConstants.accentAmber.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: AppConstants.accentAmber, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OFFICIAL PLANNING NOTICE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppConstants.accentAmber,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'This selection is a planning signal. It does not change your entitlement or permanently lock your FPS.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.primaryNavy,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                                color: Colors.red.shade800, fontSize: 12),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton.icon(
                        onPressed: (_isSubmitting || !_isChoiceWindowOpen) ? null : _submitIntent,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(_isChoiceWindowOpen ? Icons.check_circle_outline : Icons.lock_outline, size: 20),
                        label: Text(
                          _isSubmitting
                              ? 'Recording Planning Signal...'
                              : (!_isChoiceWindowOpen
                                  ? 'Choice Window Closed (Demand Locked)'
                                  : (isHomeFps
                                      ? 'Confirm Home FPS Intent'
                                      : 'Confirm Portability Intent Signal')),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_isChoiceWindowOpen
                              ? Colors.grey.shade600
                              : (isHomeFps
                                  ? AppConstants.primaryNavy
                                  : AppConstants.accentBlue),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCommodityChoiceChip(
      String label, String value, IconData icon) {
    final isSelected = _selectedCommodityOption == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : AppConstants.primaryNavy,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppConstants.primaryNavy,
        ),
      ),
      selected: isSelected,
      selectedColor: AppConstants.primaryNavy,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppConstants.primaryNavy : AppConstants.cardBorder,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedCommodityOption = value;
          });
        }
      },
    );
  }

  Widget _buildQuantitySlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppConstants.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.primaryNavy,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${value.toStringAsFixed(0)} kg',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / 5).round(),
              activeColor: color,
              label: '${value.toStringAsFixed(0)} kg',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
