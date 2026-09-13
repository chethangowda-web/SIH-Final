import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class WhatsappUssdSimulatorDialog extends StatefulWidget {
  const WhatsappUssdSimulatorDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const WhatsappUssdSimulatorDialog(),
    );
  }

  @override
  State<WhatsappUssdSimulatorDialog> createState() => _WhatsappUssdSimulatorDialogState();
}

class _WhatsappUssdSimulatorDialogState extends State<WhatsappUssdSimulatorDialog> {
  String _selectedChannel = 'WHATSAPP';
  final TextEditingController _cardIdController = TextEditingController(text: 'RC-KA-000002');
  final TextEditingController _messageController = TextEditingController(text: 'RICE 20KG FPS-KA-BAG-0001');
  bool _isSending = false;
  String? _responseLog;

  Future<void> _submitChannelSimulation() async {
    setState(() {
      _isSending = true;
      _responseLog = null;
    });

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/intent/simulate-channel');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'channel': _selectedChannel,
          'beneficiary_card_id': _cardIdController.text.trim(),
          'raw_message_text': _messageController.text.trim(),
          'cycle_id': '2026-10',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        setState(() {
          _responseLog = data['response_message'] ?? 'Intent registered successfully!';
          _isSending = false;
        });
      } else {
        setState(() {
          _responseLog = 'Failed: ${response.statusCode} - ${response.body}';
          _isSending = false;
        });
      }
    } catch (e) {
      setState(() {
        _responseLog = 'Network Error: $e';
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.phone_android_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rural & Feature-Phone Intent Simulator',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Demonstrates USSD (*99*14#) / WhatsApp / SMS intent declaration for non-smartphone users.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Channel Selector
            const Text('Select Access Gateway Channel:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildChannelChip('WHATSAPP', Icons.chat_rounded, Colors.green),
                const SizedBox(width: 8),
                _buildChannelChip('USSD', Icons.dialpad_rounded, Colors.amber),
                const SizedBox(width: 8),
                _buildChannelChip('SMS', Icons.sms_rounded, Colors.blue),
                const SizedBox(width: 8),
                _buildChannelChip('IVR', Icons.phone_callback_rounded, Colors.purple),
              ],
            ),
            const SizedBox(height: 16),

            // Card ID Input
            TextField(
              controller: _cardIdController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Beneficiary Ration Card ID',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),

            // Command / Text Input
            TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: _selectedChannel == 'USSD' ? 'USSD Dial Code e.g. *99*14#' : 'Incoming Message Text',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Preset Buttons
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Preset 1: WhatsApp Rice 20KG', style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: const Color(0xFF1E293B),
                  onPressed: () {
                    setState(() {
                      _selectedChannel = 'WHATSAPP';
                      _messageController.text = 'RICE 20KG FPS-KA-BAG-0001';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Preset 2: USSD Code *99*14#', style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: const Color(0xFF1E293B),
                  onPressed: () {
                    setState(() {
                      _selectedChannel = 'USSD';
                      _messageController.text = '*99*14#';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _submitChannelSimulation,
                icon: _isSending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_isSending ? 'Transmitting Gateway Packet...' : 'Simulate Incoming Rural Intent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            if (_responseLog != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  _responseLog!,
                  style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildChannelChip(String channel, IconData icon, Color color) {
    final isSelected = _selectedChannel == channel;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : color),
      label: Text(channel, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color(0xFFCBD5E1))),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.8),
      backgroundColor: const Color(0xFF1E293B),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedChannel = channel;
            if (channel == 'USSD') {
              _messageController.text = '*99*14#';
            } else if (channel == 'WHATSAPP') {
              _messageController.text = 'RICE 20KG FPS-KA-BAG-0001';
            }
          });
        }
      },
    );
  }
}
