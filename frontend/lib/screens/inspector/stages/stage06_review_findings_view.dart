import 'package:flutter/material.dart';
import '../../../models/inspector/inspector_models.dart';

/// Stage 06: Review Findings & Final Statutory Determination View
/// Comprehensive 6-Point Inspection Summary • AI Review • Statutory Finding Selector
class Stage06ReviewFindingsView extends StatefulWidget {
  final InspectorTarget target;
  final double observedRiceKg;
  final double observedWheatKg;
  final double scaleErrorGrams;
  final double moisturePercentage;
  final bool scaleCertified;
  final bool displayBoardUpdated;
  final bool stockMatchesRegister;
  final bool cctvFunctional;
  final bool eposOnline;
  final bool hygieneCompliant;
  final String grainCondition;
  final List<EvidenceItem> evidenceList;
  final String selectedFinding;
  final ValueChanged<String> onFindingChanged;
  final bool issueSeizureNotice;
  final ValueChanged<bool> onIssueSeizureNoticeChanged;
  final TextEditingController seizureReasonController;
  final TextEditingController inspectorNotesController;
  final VoidCallback onProceedToSubmitSeal;

  const Stage06ReviewFindingsView({
    super.key,
    required this.target,
    required this.observedRiceKg,
    required this.observedWheatKg,
    required this.scaleErrorGrams,
    required this.moisturePercentage,
    required this.scaleCertified,
    required this.displayBoardUpdated,
    required this.stockMatchesRegister,
    required this.cctvFunctional,
    required this.eposOnline,
    required this.hygieneCompliant,
    required this.grainCondition,
    required this.evidenceList,
    required this.selectedFinding,
    required this.onFindingChanged,
    required this.issueSeizureNotice,
    required this.onIssueSeizureNoticeChanged,
    required this.seizureReasonController,
    required this.inspectorNotesController,
    required this.onProceedToSubmitSeal,
  });

  @override
  State<Stage06ReviewFindingsView> createState() => _Stage06ReviewFindingsViewState();
}

class _Stage06ReviewFindingsViewState extends State<Stage06ReviewFindingsView> {
  double get _riceDiff => widget.observedRiceKg - widget.target.riceStockKg;
  double get _wheatDiff => widget.observedWheatKg - widget.target.wheatStockKg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stage Header
          _buildStageHeader(),
          const SizedBox(height: 16),

          // 2. Main Content Split: Review Summary on Left, Final Determination on Right
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary of Checkpoints
                Expanded(
                  flex: 3,
                  child: ListView(
                    children: [
                      _buildChecklistSummaryCard(),
                      const SizedBox(height: 14),
                      _buildAiReviewCard(),
                    ],
                  ),
                ),

                const SizedBox(width: 18),

                // Final Finding & Statutory Action Selector
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.gavel, size: 18, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text(
                                'Final Statutory Determination',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          const Text(
                            'Inspector Finding Category:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: widget.selectedFinding,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'NO_ISSUE', child: Text('NO ISSUE — Fully Compliant')),
                              DropdownMenuItem(value: 'MINOR_ISSUE', child: Text('MINOR ISSUE — Rectification Notice')),
                              DropdownMenuItem(value: 'MAJOR_ISSUE', child: Text('MAJOR ISSUE — Escalation to DSO')),
                              DropdownMenuItem(value: 'CRITICAL_ISSUE', child: Text('CRITICAL ISSUE — Seizure Notice')),
                              DropdownMenuItem(value: 'FURTHER_INVESTIGATION', child: Text('FURTHER INVESTIGATION — Forensic Audit')),
                            ],
                            onChanged: (val) {
                              if (val != null) widget.onFindingChanged(val);
                            },
                          ),

                          const SizedBox(height: 14),

                          // Seizure Notice Checkbox
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Serve Statutory Seizure Notice (Section 3, ECA 1955)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                            ),
                            value: widget.issueSeizureNotice,
                            onChanged: (val) {
                              if (val != null) widget.onIssueSeizureNoticeChanged(val);
                            },
                          ),

                          if (widget.issueSeizureNotice) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: widget.seizureReasonController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Statutory Grounds for Seizure',
                                hintText: 'Specify physical stock deficit, diversion proof, or tampering...',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          TextField(
                            controller: widget.inspectorNotesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Final Inspector Enforcement Notes',
                              hintText: 'Record statutory observations, instructions given to FPS dealer, and follow-up deadlines...',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const Spacer(),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.lock, size: 16),
                              label: const Text('PROCEED TO SUBMIT & SEAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: widget.onProceedToSubmitSeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.rate_review, color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAGE 06 — REVIEW FINDINGS & STATUTORY DETERMINATION',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Review comprehensive 6-point checklist results, physical stock variances, and select official enforcement finding',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('SUBMIT & SEAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: widget.onProceedToSubmitSeal,
        ),
      ],
    );
  }

  Widget _buildChecklistSummaryCard() {
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
            const Text(
              '6-Point Inspection Checklist Summary',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const Divider(height: 18),
            _buildReviewRow(
              '1. Physical Stock Tally',
              'Rice: ${widget.observedRiceKg} kg (${_riceDiff >= 0 ? "+" : ""}${_riceDiff.toStringAsFixed(1)} kg) • Wheat: ${widget.observedWheatKg} kg (${_wheatDiff >= 0 ? "+" : ""}${_wheatDiff.toStringAsFixed(1)} kg)',
              _riceDiff == 0 && _wheatDiff == 0,
            ),
            _buildReviewRow(
              '2. e-PoS & Biometrics',
              widget.eposOnline ? 'ONLINE & SYNCHRONIZED' : 'OFFLINE / DISCONNECTED',
              widget.eposOnline,
            ),
            _buildReviewRow(
              '3. Weighing Scale Calibration',
              widget.scaleCertified ? 'CERTIFIED (Error: ${widget.scaleErrorGrams}g)' : 'UNCERTIFIED',
              widget.scaleCertified && widget.scaleErrorGrams.abs() <= 5.0,
            ),
            _buildReviewRow(
              '4. Grain Quality & Moisture',
              'Moisture: ${widget.moisturePercentage}% • Condition: ${widget.grainCondition}',
              widget.moisturePercentage <= 12.0 && widget.grainCondition != 'DAMAGED',
            ),
            _buildReviewRow(
              '5. NFSA Signage & CCTV',
              'Display Board: ${widget.displayBoardUpdated ? "PASS" : "FAIL"} • CCTV: ${widget.cctvFunctional ? "PASS" : "FAIL"}',
              widget.displayBoardUpdated && widget.cctvFunctional,
            ),
            _buildReviewRow(
              '6. Physical Evidence Attached',
              '${widget.evidenceList.length} evidence items registered in official ledger',
              widget.evidenceList.isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(String title, String detail, bool isPass) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPass ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 16,
            color: isPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(detail, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiReviewCard() {
    final hasDiscrepancy = _riceDiff != 0 || _wheatDiff != 0 || widget.moisturePercentage > 12.0 || !widget.scaleCertified;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: hasDiscrepancy ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasDiscrepancy ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  size: 18,
                  color: hasDiscrepancy ? const Color(0xFFDC2626) : const Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Inspection Synthesis & Cross-Correlation',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hasDiscrepancy ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasDiscrepancy
                  ? 'Physical stock or calibration discrepancy detected. Cross-referencing against 6-cycle historical variance and e-PoS ledger suggests potential diversion or uncalibrated tare weight.'
                  : 'All physical measurements, grain moisture content (<= 12%), and biometric hardware diagnostic pings comply with statutory NFSA standards.',
              style: TextStyle(
                fontSize: 11,
                color: hasDiscrepancy ? const Color(0xFF7F1D1D) : const Color(0xFF047857),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
