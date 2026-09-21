import 'package:flutter/material.dart';

/// Top Government Header for Field Food Inspector Command Center
/// Real District Selector • Dynamic Officer Profile • Operational State
class InspectorTopHeader extends StatelessWidget {
  final String activeDistrict;
  final List<String> availableDistricts;
  final ValueChanged<String> onDistrictChanged;
  final String activeCycle;
  final ValueChanged<String> onCycleChanged;
  final String officerName;
  final int notificationCount;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onLogout;

  const InspectorTopHeader({
    super.key,
    required this.activeDistrict,
    required this.availableDistricts,
    required this.onDistrictChanged,
    required this.activeCycle,
    required this.onCycleChanged,
    required this.officerName,
    this.notificationCount = 0,
    this.onNotificationsTap,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          // 1. Title & Government Seal Label
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'FIELD FOOD INSPECTOR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '• Inspection & Verification Command Center',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Text(
                'Statutory 6-Point Physical Verification & Geofenced Anti-Tamper Enforcement • NFSA 2013',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          const Spacer(),

          // 2. District Selector (from Real DB)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_city, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                const Text(
                  'District: ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableDistricts.contains(activeDistrict) ? activeDistrict : (availableDistricts.isNotEmpty ? availableDistricts.first : 'Bengaluru Urban'),
                    isDense: true,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    items: availableDistricts.map((d) {
                      return DropdownMenuItem<String>(
                        value: d,
                        child: Text(d),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) onDistrictChanged(val);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 3. Cycle Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                const Text(
                  'Cycle: ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: activeCycle,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    items: const [
                      DropdownMenuItem(value: '2026-09', child: Text('2026-09 (Active)')),
                      DropdownMenuItem(value: '2026-08', child: Text('2026-08 (Closed)')),
                    ],
                    onChanged: (val) {
                      if (val != null) onCycleChanged(val);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 4. System Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text(
                  'OPERATIONAL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 5. Notifications Icon with Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, size: 20, color: Color(0xFF64748B)),
                onPressed: onNotificationsTap,
                tooltip: 'Notifications',
              ),
              if (notificationCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '$notificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 8),

          // 6. Officer Profile Badge & Logout Menu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    officerName.isNotEmpty ? officerName[0].toUpperCase() : 'I',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      officerName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Text(
                      'Field Food Inspector',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                if (onLogout != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 16, color: Color(0xFF64748B)),
                    onPressed: onLogout,
                    tooltip: 'Switch Persona / Logout',
                    constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
