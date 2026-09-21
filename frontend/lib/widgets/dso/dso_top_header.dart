import 'package:flutter/material.dart';

class DsoTopHeader extends StatelessWidget {
  final String activeCycle;
  final String selectedDistrict;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onCycleChanged;
  final VoidCallback? onNotificationsTap;
  final String officerName;

  const DsoTopHeader({
    super.key,
    required this.activeCycle,
    required this.selectedDistrict,
    required this.onDistrictChanged,
    required this.onCycleChanged,
    this.onNotificationsTap,
    this.officerName = 'Dr. S. Kumar',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Left Titles
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'DSO Command Center',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'District Supply Officer',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 32),

            // District Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDistrict,
                  isDense: true,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'Ramanagara', child: Text('District: Ramanagara')),
                    DropdownMenuItem(value: 'Bengaluru Urban', child: Text('District: Bengaluru Urban')),
                    DropdownMenuItem(value: 'Mandya', child: Text('District: Mandya')),
                  ],
                  onChanged: onDistrictChanged,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Active Cycle Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Active Cycle: ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: activeCycle,
                      isDense: true,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(
                          value: '2026-09',
                          child: Text('2026-09 (Active)'),
                        ),
                        DropdownMenuItem(
                          value: '2026-08',
                          child: Text('2026-08 (Closed)'),
                        ),
                      ],
                      onChanged: onCycleChanged,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // System Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.circle, color: Color(0xFF16A34A), size: 8),
                  SizedBox(width: 6),
                  Text(
                    'Operational',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Notifications Bell
            InkWell(
              onTap: onNotificationsTap,
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 22),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // User Profile Badge
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF1E3A8A),
                  child: Text(
                    officerName.startsWith('Dr') ? 'DS' : officerName.substring(0, 2).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      officerName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Text(
                      'District Supply Officer',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
