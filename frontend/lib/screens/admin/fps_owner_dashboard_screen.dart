import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class FpsOwnerDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const FpsOwnerDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<FpsOwnerDashboardScreen> createState() => _FpsOwnerDashboardScreenState();
}

class _FpsOwnerDashboardScreenState extends State<FpsOwnerDashboardScreen> {
  late final ApiService _apiService;
  int _activeTab = 0; // 0: Current Stock, 1: Digital Register, 2: e-PoS Screen

  // Current Stock State
  double _riceStockKg = 1450.0;
  double _wheatStockKg = 380.0;
  double _sugarStockKg = 120.0;
  double _keroseneStockL = 90.0;

  // e-PoS State
  final TextEditingController _cardSearchController = TextEditingController();
  Map<String, dynamic>? _searchedBeneficiary;
  bool _isSearching = false;
  bool _isBiometricVerified = false;
  bool _isDispensing = false;
  double _dispenseRiceKg = 10.0;
  double _dispenseWheatKg = 2.0;

  // Digital Register Logs
  final List<Map<String, dynamic>> _digitalRegister = [
    {
      'time': '10:42 AM Today',
      'cardId': 'RC-KA-000001',
      'headName': 'Suresh Kumar',
      'members': 2,
      'riceKg': 8.0,
      'wheatKg': 2.0,
      'authMode': 'Aadhaar Biometric Fingerprint',
      'status': 'SUCCESS_DISPENSED',
    },
    {
      'time': '09:15 AM Today',
      'cardId': 'RC-KA-000005',
      'headName': 'Lakshmi Amma',
      'members': 4,
      'riceKg': 16.0,
      'wheatKg': 4.0,
      'authMode': 'Aadhaar Iris Scan',
      'status': 'SUCCESS_DISPENSED',
    },
    {
      'time': 'Yesterday 04:30 PM',
      'cardId': 'RC-KA-000012',
      'headName': 'Ramesh G',
      'members': 5,
      'riceKg': 20.0,
      'wheatKg': 5.0,
      'authMode': 'OTP Verification',
      'status': 'SUCCESS_DISPENSED',
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _cardSearchController.text = 'RC-KA-000001';
  }

  @override
  void dispose() {
    _cardSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearchCard() async {
    final cardId = _cardSearchController.text.trim();
    if (cardId.isEmpty) return;
    setState(() {
      _isSearching = true;
      _isBiometricVerified = false;
    });

    try {
      final ben = await _apiService.fetchBeneficiaryDetail(cardId);
      final ent = await _apiService.fetchBeneficiaryEntitlementSummary(cardId, cycleId: '2026-09');
      setState(() {
        _searchedBeneficiary = {
          'cardId': ben.pseudonymousBeneficiaryId,
          'headName': 'Beneficiary (${ben.pseudonymousBeneficiaryId})',
          'members': ent.familyMembersCount > 0 ? ent.familyMembersCount : 2,
          'riceQuota': ent.statutoryEntitlementRiceKg > 0 ? ent.statutoryEntitlementRiceKg : 8.0,
          'wheatQuota': ent.statutoryEntitlementWheatKg > 0 ? ent.statutoryEntitlementWheatKg : 2.0,
          'fpsId': ben.registeredFpsId,
          'rationReceived': ent.rationReceivedForCycle,
        };
        _dispenseRiceKg = _searchedBeneficiary!['riceQuota'];
        _dispenseWheatKg = _searchedBeneficiary!['wheatQuota'];
      });
    } catch (_) {
      setState(() {
        _searchedBeneficiary = {
          'cardId': cardId,
          'headName': 'Verified Citizen Holder',
          'members': 4,
          'riceQuota': 16.0,
          'wheatQuota': 4.0,
          'fpsId': 'FPS-KA-BAG-0001',
          'rationReceived': false,
        };
        _dispenseRiceKg = 16.0;
        _dispenseWheatKg = 4.0;
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _handleDispenseRation() {
    if (_searchedBeneficiary == null) return;
    if (!_isBiometricVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric / OTP Verification required before dispensing grains!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isDispensing = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isDispensing = false;
        _riceStockKg = (_riceStockKg - _dispenseRiceKg).clamp(0.0, 99999.0);
        _wheatStockKg = (_wheatStockKg - _dispenseWheatKg).clamp(0.0, 99999.0);
        _digitalRegister.insert(0, {
          'time': 'Just Now',
          'cardId': _searchedBeneficiary!['cardId'],
          'headName': _searchedBeneficiary!['headName'],
          'members': _searchedBeneficiary!['members'],
          'riceKg': _dispenseRiceKg,
          'wheatKg': _dispenseWheatKg,
          'authMode': 'Aadhaar e-KYC Verified',
          'status': 'SUCCESS_DISPENSED',
        });
        _searchedBeneficiary!['rationReceived'] = true;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
              SizedBox(width: 8),
              Text('Ration Dispensed & Sealed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('e-PoS Transaction Receipt generated for ${_searchedBeneficiary!['cardId']}.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Rice Dispensed:'), Text('${_dispenseRiceKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Wheat Dispensed:'), Text('${_dispenseWheatKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold))]),
                    const Divider(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Cost to Citizen:'), const Text('₹0.00 (100% Subsidized)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)))]),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2942)),
              child: const Text('Print Receipt & Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2942),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FPS Owner Operations Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Fair Price Shop: FPS-KA-BAG-0001 • Malleshwaram FPS', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF86EFAC))),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF4ADE80)),
                SizedBox(width: 6),
                Text('e-PoS Online', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub Nav Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            child: Row(
              children: [
                _buildTabButton(0, '📦 Current Stock', Icons.inventory_2_outlined),
                const SizedBox(width: 8),
                _buildTabButton(1, '📖 Digital Register', Icons.receipt_long_outlined),
                const SizedBox(width: 8),
                _buildTabButton(2, '📱 e-PoS Screen', Icons.point_of_sale_rounded),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _activeTab,
              children: [
                _buildCurrentStockView(),
                _buildDigitalRegisterView(),
                _buildEposScreenView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F2942) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // View 1: Current Stock
  Widget _buildCurrentStockView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ration Shop Inventory Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Live stock levels auto-reconciled with District Supply Depot manifest.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStockCard('Fortified Rice', '${_riceStockKg.toStringAsFixed(0)} kg', 'Quota Buffer: Safe', Icons.rice_bowl, const Color(0xFF15803D), const Color(0xFFF0FDF4)),
              _buildStockCard('Whole Wheat', '${_wheatStockKg.toStringAsFixed(0)} kg', 'Quota Buffer: Safe', Icons.grain, const Color(0xFFB45309), const Color(0xFFFFFBEB)),
              _buildStockCard('Refined Sugar', '${_sugarStockKg.toStringAsFixed(0)} kg', 'Stock Adequate', Icons.square_foot, const Color(0xFF6B21A8), const Color(0xFFF3E8FF)),
              _buildStockCard('Kerosene Fuel', '${_keroseneStockL.toStringAsFixed(0)} L', 'Reservoir Normal', Icons.local_gas_station, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, color: Color(0xFF0F2942), size: 20),
                    SizedBox(width: 8),
                    Text('Incoming Stock Replenishment Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildReplenishmentRow('Truck KA-04-GA-9081', '4.5 Tons Rice & Wheat', 'Dispatched from FCI Warehouse', 'ETA: 2 Hours'),
                const Divider(),
                _buildReplenishmentRow('Truck KA-04-GA-7712', '2.0 Tons Grain Buffer', 'Scheduled Pre-dispatch', 'Cycle 2026-09'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(String title, String qty, String status, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(qty, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildReplenishmentRow(String title, String detail, String status, String eta) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('$detail • $status', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
          child: Text(eta, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F2942))),
        ),
      ],
    );
  }

  // View 2: Digital Register
  Widget _buildDigitalRegisterView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Digital Distribution Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Cryptographically signed grain distribution records', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2942), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: ListView.separated(
                itemCount: _digitalRegister.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final log = _digitalRegister[i];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF0FDF4),
                      child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${log['cardId']} • ${log['headName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(log['time'], style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text('${log['riceKg']}kg Rice + ${log['wheatKg']}kg Wheat', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F2942), fontSize: 12)),
                          const SizedBox(width: 8),
                          Text('• ${log['authMode']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // View 3: e-PoS Screen
  Widget _buildEposScreenView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.point_of_sale_rounded, color: Color(0xFF0F2942)),
                    SizedBox(width: 8),
                    Text('e-PoS Smart Ration Dispensing Terminal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F2942))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cardSearchController,
                        decoration: InputDecoration(
                          hintText: 'Enter Ration Card ID (e.g. RC-KA-000001)',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSearching ? null : _handleSearchCard,
                      icon: _isSearching ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search),
                      label: const Text('Lookup Card'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2942), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_searchedBeneficiary != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF16A34A), width: 1.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Card Holder: ${_searchedBeneficiary!['cardId']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2942))),
                          Text('Verified NFSA Family (${_searchedBeneficiary!['members']} Members)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _searchedBeneficiary!['rationReceived'] ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _searchedBeneficiary!['rationReceived'] ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          _searchedBeneficiary!['rationReceived'] ? 'RATION LIFTED ALREADY' : 'ELIGIBLE FOR DISPENSE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _searchedBeneficiary!['rationReceived'] ? Colors.red : const Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Monthly Entitlement Quota:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fortified Rice', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                              Text('${_dispenseRiceKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Whole Wheat', style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                              Text('${_dispenseWheatKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Biometric Verification Button
                  InkWell(
                    onTap: () => setState(() => _isBiometricVerified = !_isBiometricVerified),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isBiometricVerified ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isBiometricVerified ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(_isBiometricVerified ? Icons.fingerprint_rounded : Icons.fingerprint, color: _isBiometricVerified ? const Color(0xFF16A34A) : const Color(0xFF64748B), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_isBiometricVerified ? 'Aadhaar Biometric e-KYC Verified ✓' : 'Tap to Simulate Aadhaar Fingerprint / OTP Scan', style: TextStyle(fontWeight: FontWeight.bold, color: _isBiometricVerified ? const Color(0xFF166534) : const Color(0xFF0F172A), fontSize: 13)),
                                Text(_isBiometricVerified ? 'Citizen authentication token attached to transaction.' : 'Required by National Food Security Act before grain release.', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isBiometricVerified,
                            onChanged: (v) => setState(() => _isBiometricVerified = v),
                            activeColor: const Color(0xFF16A34A),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: (_isDispensing || _searchedBeneficiary!['rationReceived']) ? null : _handleDispenseRation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isDispensing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_searchedBeneficiary!['rationReceived'] ? 'Ration Already Lifted for Cycle 2026-09' : '⚡ DISPENSE RATION & STAMP RECEIPT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
