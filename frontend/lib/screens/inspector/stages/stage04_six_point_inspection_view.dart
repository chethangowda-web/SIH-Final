import 'package:flutter/material.dart';
import '../../../models/inspector/inspector_models.dart';

/// Stage 04: 6-Point Statutory Field Inspection Checklist View
/// Stock Variance • e-PoS Diagnostic • Scale Weighment • Quality • Compliance • Grievance
class Stage04SixPointInspectionView extends StatefulWidget {
  final InspectorTarget target;
  final TextEditingController observedRiceController;
  final TextEditingController observedWheatController;
  final TextEditingController scaleErrorController;
  final TextEditingController moistureController;
  final TextEditingController remarksController;
  final bool scaleCertified;
  final ValueChanged<bool> onScaleCertifiedChanged;
  final bool displayBoardUpdated;
  final ValueChanged<bool> onDisplayBoardUpdatedChanged;
  final bool stockMatchesRegister;
  final ValueChanged<bool> onStockMatchesRegisterChanged;
  final bool cctvFunctional;
  final ValueChanged<bool> onCctvFunctionalChanged;
  final bool eposOnline;
  final ValueChanged<bool> onEposOnlineChanged;
  final bool hygieneCompliant;
  final ValueChanged<bool> onHygieneCompliantChanged;
  final String grainCondition;
  final ValueChanged<String> onGrainConditionChanged;
  final VoidCallback onRunEposDiagnostic;
  final bool isRunningEposDiagnostic;
  final Map<String, dynamic>? eposDiagnosticResult;
  final VoidCallback onProceedToEvidence;

  const Stage04SixPointInspectionView({
    super.key,
    required this.target,
    required this.observedRiceController,
    required this.observedWheatController,
    required this.scaleErrorController,
    required this.moistureController,
    required this.remarksController,
    required this.scaleCertified,
    required this.onScaleCertifiedChanged,
    required this.displayBoardUpdated,
    required this.onDisplayBoardUpdatedChanged,
    required this.stockMatchesRegister,
    required this.onStockMatchesRegisterChanged,
    required this.cctvFunctional,
    required this.onCctvFunctionalChanged,
    required this.eposOnline,
    required this.onEposOnlineChanged,
    required this.hygieneCompliant,
    required this.onHygieneCompliantChanged,
    required this.grainCondition,
    required this.onGrainConditionChanged,
    required this.onRunEposDiagnostic,
    required this.isRunningEposDiagnostic,
    required this.eposDiagnosticResult,
    required this.onProceedToEvidence,
  });

  @override
  State<Stage04SixPointInspectionView> createState() => _Stage04SixPointInspectionViewState();
}

class _Stage04SixPointInspectionViewState extends State<Stage04SixPointInspectionView> {
  double get _riceVariance {
    final obs = double.tryParse(widget.observedRiceController.text) ?? widget.target.riceStockKg;
    return obs - widget.target.riceStockKg;
  }

  double get _wheatVariance {
    final obs = double.tryParse(widget.observedWheatController.text) ?? widget.target.wheatStockKg;
    return obs - widget.target.wheatStockKg;
  }

  double get _complianceScore {
    int points = 0;
    if (widget.scaleCertified) points += 20;
    if (widget.displayBoardUpdated) points += 15;
    if (widget.stockMatchesRegister && _riceVariance == 0 && _wheatVariance == 0) points += 25;
    if (widget.cctvFunctional) points += 10;
    if (widget.eposOnline) points += 15;
    if (widget.hygieneCompliant) points += 15;
    return points.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final score = _complianceScore;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stage Title & Score HUD
          _buildStageHeader(score),
          const SizedBox(height: 16),

          // 2. Checklist Items List
          Expanded(
            child: ListView(
              children: [
                _buildCheck01PhysicalStock(),
                const SizedBox(height: 14),
                _buildCheck02EposVerification(),
                const SizedBox(height: 14),
                _buildCheck03ScaleWeighment(),
                const SizedBox(height: 14),
                _buildCheck04QualityFoodSafety(),
                const SizedBox(height: 14),
                _buildCheck05ComplianceCleanliness(),
                const SizedBox(height: 14),
                _buildCheck06BeneficiaryExperience(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader(double score) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fact_check, color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAGE 04 — STATUTORY 6-POINT PHYSICAL INSPECTION',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Execute on-site physical stock count, weighing scale calibration, grain moisture, and e-PoS diagnostic ping',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: score >= 80 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: score >= 80 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Text(
                'COMPLIANCE SCORE: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: score >= 80 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                ),
              ),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: score >= 80 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('EVIDENCE CAPTURE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: widget.onProceedToEvidence,
        ),
      ],
    );
  }

  Widget _buildCheck01PhysicalStock() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge('CHECK 01', const Color(0xFF2563EB)),
                const SizedBox(width: 10),
                const Text(
                  'Physical Stock Verification vs Digital Register',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                // Rice Tally
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rice Stock Tally', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Recorded in DB: ${widget.target.riceStockKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: widget.observedRiceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Physical Observed Rice (kg)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Variance: ${_riceVariance >= 0 ? "+" : ""}${_riceVariance.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _riceVariance == 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Wheat Tally
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wheat Stock Tally', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Recorded in DB: ${widget.target.wheatStockKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: widget.observedWheatController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Physical Observed Wheat (kg)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Variance: ${_wheatVariance >= 0 ? "+" : ""}${_wheatVariance.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _wheatVariance == 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Physical stock matches physical and digital register records without unexplained deficit'),
              value: widget.stockMatchesRegister,
              onChanged: (val) {
                if (val != null) widget.onStockMatchesRegisterChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheck02EposVerification() {
    final diag = widget.eposDiagnosticResult;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge('CHECK 02', const Color(0xFF059669)),
                const SizedBox(width: 10),
                const Text(
                  'e-PoS Terminal & Biometric Scanner Diagnostic',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: widget.isRunningEposDiagnostic
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.network_ping, size: 14),
                  label: const Text('RUN DIAGNOSTIC PING', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: widget.isRunningEposDiagnostic ? null : widget.onRunEposDiagnostic,
                ),
              ],
            ),
            const Divider(height: 20),
            if (diag != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF059669), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Terminal: ${diag['terminal_id']} • Network: ${diag['network_status']} • Latency: ${diag['latency_ms']} ms • Biometrics: ${diag['biometric_scanner']} (${diag['scanner_status']})',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('e-PoS terminal is online, synchronized, and biometric fingerprint/iris scanner is fully operational'),
              value: widget.eposOnline,
              onChanged: (val) {
                if (val != null) widget.onEposOnlineChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheck03ScaleWeighment() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge('CHECK 03', const Color(0xFFD97706)),
                const SizedBox(width: 10),
                const Text(
                  'Electronic Weighbridge & Scale Calibration',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.scaleErrorController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Scale Calibration Error (Grams)',
                      hintText: '0.0 (tolerance ±5.0g)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Scale has valid Legal Metrology certification stamp and zero tare weight offset'),
                    value: widget.scaleCertified,
                    onChanged: (val) {
                      if (val != null) widget.onScaleCertifiedChanged(val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheck04QualityFoodSafety() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge('CHECK 04', const Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                const Text(
                  'Food Safety & Grain Quality Standards',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.moistureController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Grain Moisture Content (%)',
                      hintText: '11.2 (statutory ceiling <= 12.0%)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.grainCondition,
                    decoration: const InputDecoration(
                      labelText: 'Grain Physical Quality',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GOOD', child: Text('GOOD (Fit for NFSA Distribution)')),
                      DropdownMenuItem(value: 'FAIR', child: Text('FAIR (Acceptable, Low Broken %)')),
                      DropdownMenuItem(value: 'DAMAGED', child: Text('DAMAGED (Discolored / Infested)')),
                    ],
                    onChanged: (val) {
                      if (val != null) widget.onGrainConditionChanged(val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Storage is dry, hygienic, on dunnage pallets, with no moisture damage or pest infestation'),
              value: widget.hygieneCompliant,
              onChanged: (val) {
                if (val != null) widget.onHygieneCompliantChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheck05ComplianceCleanliness() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge('CHECK 05', const Color(0xFF0F766E)),
                const SizedBox(width: 10),
                const Text(
                  'Statutory Signage, CCTV & Shop Operations',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('NFSA Entitlement & Rate Board displayed prominently in Kannada & English'),
                    value: widget.displayBoardUpdated,
                    onChanged: (val) {
                      if (val != null) widget.onDisplayBoardUpdatedChanged(val);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CCTV surveillance camera operational with at least 30-day digital retention'),
                    value: widget.cctvFunctional,
                    onChanged: (val) {
                      if (val != null) widget.onCctvFunctionalChanged(val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheck06BeneficiaryExperience() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge('CHECK 06', const Color(0xFF4338CA)),
                const SizedBox(width: 10),
                const Text(
                  'Beneficiary Experience & Grievance Review',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 20),
            TextField(
              controller: widget.remarksController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Inspector Observations & Beneficiary Interviews',
                hintText: 'Record on-site beneficiary feedback, queue wait time, or any reported short weighment...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
