import 'package:flutter/material.dart';

/// Dark Navy Command Navigation Sidebar for Field Food Inspector Portal
/// Desktop-first Layout • Government Operations Design
class InspectorSidebar extends StatelessWidget {
  final int activeStage; // 0 to 7 (maps to Stages 01 to 08)
  final int activeSection; // 0 = Workflow, 1 = AI, 2 = Exceptions, 3 = Trace, 4 = DataSources
  final ValueChanged<int> onStageSelected;
  final ValueChanged<int> onSectionSelected;
  final int pendingOrdersCount;
  final int exceptionsCount;
  final String district;
  final String officerName;

  const InspectorSidebar({
    super.key,
    required this.activeStage,
    required this.activeSection,
    required this.onStageSelected,
    required this.onSectionSelected,
    this.pendingOrdersCount = 0,
    this.exceptionsCount = 0,
    this.district = 'Bengaluru Urban',
    this.officerName = 'Field Food Inspector',
  });

  static const List<Map<String, dynamic>> _stages = [
    {'number': '01', 'label': 'Select Target', 'icon': Icons.track_changes_outlined},
    {'number': '02', 'label': 'Travel & Geofence', 'icon': Icons.navigation_outlined},
    {'number': '03', 'label': 'Verify FPS & Delivery', 'icon': Icons.local_shipping_outlined},
    {'number': '04', 'label': '6-Point Inspection', 'icon': Icons.fact_check_outlined},
    {'number': '05', 'label': 'Evidence & Photos', 'icon': Icons.photo_camera_outlined},
    {'number': '06', 'label': 'Review Findings', 'icon': Icons.rate_review_outlined},
    {'number': '07', 'label': 'Submit & Seal', 'icon': Icons.lock_outline},
    {'number': '08', 'label': 'Sealed Record', 'icon': Icons.verified_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark Navy
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Brand
          _buildBrandHeader(),

          const Divider(color: Color(0xFF1E293B), height: 1),

          // 2. Stage Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSectionHeader('INSPECTION WORKFLOW'),
                ..._stages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final stage = entry.value;
                  final isSelected = activeSection == 0 && activeStage == idx;
                  return _buildStageItem(
                    number: stage['number'] as String,
                    label: stage['label'] as String,
                    icon: stage['icon'] as IconData,
                    isSelected: isSelected,
                    badge: (idx == 0 && pendingOrdersCount > 0) ? '$pendingOrdersCount' : null,
                    onTap: () {
                      onSectionSelected(0);
                      onStageSelected(idx);
                    },
                  );
                }),

                const SizedBox(height: 16),
                _buildSectionHeader('INTELLIGENCE & AUDIT'),

                _buildNavigationItem(
                  icon: Icons.psychology_outlined,
                  label: 'AI Intelligence',
                  isSelected: activeSection == 1,
                  onTap: () => onSectionSelected(1),
                ),
                _buildNavigationItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Exception Queue',
                  badge: exceptionsCount > 0 ? '$exceptionsCount' : null,
                  badgeColor: const Color(0xFFEF4444),
                  isSelected: activeSection == 2,
                  onTap: () => onSectionSelected(2),
                ),
                _buildNavigationItem(
                  icon: Icons.timeline_outlined,
                  label: 'Decision Trace',
                  isSelected: activeSection == 3,
                  onTap: () => onSectionSelected(3),
                ),
                _buildNavigationItem(
                  icon: Icons.storage_outlined,
                  label: 'Data Sources (SQLite)',
                  isSelected: activeSection == 4,
                  onTap: () => onSectionSelected(4),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),

          // 3. Officer Profile Badge at Footer
          _buildOfficerBadge(),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PDS DemandSync',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Field Food Inspector',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Color(0xFF38BDF8), size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    district,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildStageItem({
    required String number,
    required String label,
    required IconData icon,
    required bool isSelected,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    String? badge,
    Color badgeColor = const Color(0xFF2563EB),
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficerBadge() {
    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFF0B1120),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1E293B),
            child: Text(
              officerName.isNotEmpty ? officerName[0].toUpperCase() : 'I',
              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  officerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Field Food Inspector',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981), // Online green
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
