import 'package:flutter/material.dart';
import '../../../models/inspector/inspector_models.dart';

/// Stage 05: Photographic & Documentary Evidence Capture View
/// Real Evidence Ledger • AI Evidence Assistant • Statutory Chain of Custody
class Stage05EvidenceView extends StatelessWidget {
  final InspectorTarget target;
  final List<EvidenceItem> evidenceList;
  final ValueChanged<EvidenceItem> onAddEvidence;
  final VoidCallback onProceedToReview;

  const Stage05EvidenceView({
    super.key,
    required this.target,
    required this.evidenceList,
    required this.onAddEvidence,
    required this.onProceedToReview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          _buildStageHeader(context),
          const SizedBox(height: 16),

          // 2. Main Content Split: Evidence Grid + AI Assistance Drawer
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Evidence Grid
                Expanded(
                  flex: 3,
                  child: Card(
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
                              Text(
                                'Registered Evidence Records (${evidenceList.length})',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_a_photo, size: 14),
                                label: const Text('ADD EVIDENCE ITEM', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => _showAddEvidenceDialog(context),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Expanded(
                            child: evidenceList.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF94A3B8)),
                                        SizedBox(height: 12),
                                        Text(
                                          'No Physical Evidence Registered Yet',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Click "Add Evidence Item" to register on-site photographs, weighment slips, or moisture logs.',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.8,
                                    ),
                                    itemCount: evidenceList.length,
                                    itemBuilder: (context, index) {
                                      final ev = evidenceList[index];
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    ev.type,
                                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  ev.id,
                                                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              ev.description,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time, size: 10, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  ev.timestamp.isNotEmpty ? ev.timestamp : 'Timestamped on submit',
                                                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                                ),
                                                const Spacer(),
                                                const Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // AI Evidence Assistant
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Card(
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
                              const Row(
                                children: [
                                  Icon(Icons.psychology, size: 18, color: Color(0xFF2563EB)),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI Evidence Assistant',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Text(
                                'Target Shop: ${target.name}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 8),
                              _buildAiCheckItem(
                                'Weighment Scale Calibration',
                                evidenceList.any((e) => e.type == 'WEIGHMENT_SLIP'),
                              ),
                              _buildAiCheckItem(
                                'Grain Moisture & Packaging',
                                evidenceList.any((e) => e.type == 'MOISTURE_LOG' || e.type == 'STOCK_ROOM'),
                              ),
                              _buildAiCheckItem(
                                'NFSA Entitlement Display Board',
                                evidenceList.any((e) => e.type == 'DISPLAY_BOARD'),
                              ),
                              _buildAiCheckItem(
                                'Storage Hygiene & Dunnage Pallets',
                                evidenceList.any((e) => e.type == 'PHOTOGRAPH'),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'AI Evidence Advice: For statutory legal strength under ECA 1955, ensure at least one photograph of the physical stack pile with lot tags is attached.',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF475569), height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.photo_camera, color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAGE 05 — EVIDENCE CAPTURE & OBSERVATIONS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Register statutory on-site photographs, weighment calibration slips, and grain moisture meter readings',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('REVIEW FINDINGS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onProceedToReview,
        ),
      ],
    );
  }

  Widget _buildAiCheckItem(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isSatisfied ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSatisfied ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEvidenceDialog(BuildContext context) {
    String type = 'PHOTOGRAPH';
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text('Register Physical Evidence Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Evidence Type', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'PHOTOGRAPH', child: Text('Photograph: Physical Grain Sack Pile')),
                    DropdownMenuItem(value: 'WEIGHMENT_SLIP', child: Text('Document: Weighbridge Scale Tare Slip')),
                    DropdownMenuItem(value: 'MOISTURE_LOG', child: Text('Reading: Digital Grain Moisture Meter')),
                    DropdownMenuItem(value: 'DISPLAY_BOARD', child: Text('Photograph: NFSA Entitlement Board')),
                    DropdownMenuItem(value: 'SEIZURE_MEMO', child: Text('Statutory Notice: Seizure Memorandum')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => type = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Evidence Description & Finding Details',
                    hintText: 'e.g. 50 kg NFSA jute bags stacked on dunnage pallets with lot tags verified in warehouse bay 2...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () {
                if (descController.text.trim().isNotEmpty) {
                  final item = EvidenceItem(
                    id: 'EV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    type: type,
                    description: descController.text.trim(),
                    referencePath: 'DEVICE_STORAGE_${type.toLowerCase()}.jpg',
                    timestamp: DateTime.now().toString().substring(0, 19),
                    inspector: 'inspector_user',
                  );
                  onAddEvidence(item);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Register Evidence'),
            ),
          ],
        ),
      ),
    );
  }
}
