import 'package:flutter/material.dart';

class DsoSidebar extends StatelessWidget {
  final int activeStage;
  final int selectedNavIndex; // 0: Overview, 1-7: Stages 1-7, 8: AI, 9: Exceptions, 10: Decision Trace, 11: Data Sources
  final ValueChanged<int> onSelectNav;
  final int exceptionCount;
  final String district;

  const DsoSidebar({
    super.key,
    required this.activeStage,
    required this.selectedNavIndex,
    required this.onSelectNav,
    this.exceptionCount = 7,
    this.district = 'Ramanagara',
  });

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF0B132B);
    const textMuted = Color(0xFF8D99AE);
    const textBright = Colors.white;

    return Container(
      width: 250,
      color: bgNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Logo
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'PDS DemandSync',
                        style: TextStyle(
                          color: textBright,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Food Security. Smarter Decisions.',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1E293B)),

          // Navigation Links
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.dashboard_rounded,
                    label: 'Command Overview',
                    isSelected: selectedNavIndex == 0,
                  ),
                  const SizedBox(height: 8),

                  _buildNavItem(
                    index: 1,
                    stepNumber: '01',
                    label: 'Monitor & Triage',
                    isSelected: selectedNavIndex == 1,
                  ),
                  _buildNavItem(
                    index: 2,
                    stepNumber: '02',
                    label: 'Validate Demand',
                    isSelected: selectedNavIndex == 2,
                  ),
                  _buildNavItem(
                    index: 3,
                    stepNumber: '03',
                    label: 'Allocate',
                    isSelected: selectedNavIndex == 3,
                  ),
                  _buildNavItem(
                    index: 4,
                    stepNumber: '04',
                    label: 'Optimize',
                    isSelected: selectedNavIndex == 4,
                  ),
                  _buildNavItem(
                    index: 5,
                    stepNumber: '05',
                    label: 'Authorize Dispatch',
                    isSelected: selectedNavIndex == 5,
                  ),
                  _buildNavItem(
                    index: 6,
                    stepNumber: '06',
                    label: 'Verify Delivery',
                    isSelected: selectedNavIndex == 6,
                  ),
                  _buildNavItem(
                    index: 7,
                    stepNumber: '07',
                    label: 'Evaluate & Close',
                    isSelected: selectedNavIndex == 7,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(height: 1, color: Color(0xFF1E293B)),
                  ),

                  _buildNavItem(
                    index: 8,
                    icon: Icons.auto_awesome,
                    label: 'AI Intelligence',
                    isSelected: selectedNavIndex == 8,
                  ),
                  _buildNavItem(
                    index: 9,
                    icon: Icons.warning_amber_rounded,
                    label: 'Exceptions',
                    badgeCount: exceptionCount,
                    isSelected: selectedNavIndex == 9,
                  ),
                  _buildNavItem(
                    index: 10,
                    icon: Icons.timeline,
                    label: 'Decision Trace',
                    isSelected: selectedNavIndex == 10,
                  ),
                  _buildNavItem(
                    index: 11,
                    icon: Icons.storage_rounded,
                    label: 'Data Sources',
                    isSelected: selectedNavIndex == 11,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Location Footer Chip
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF090F20),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: textMuted, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      district,
                      style: const TextStyle(color: textBright, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Text(
                      'Karnataka',
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    IconData? icon,
    String? stepNumber,
    required String label,
    int? badgeCount,
    required bool isSelected,
  }) {
    const textMuted = Color(0xFF94A3B8);
    const textBright = Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onSelectNav(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (stepNumber != null)
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      stepNumber,
                      style: TextStyle(
                        color: isSelected ? Colors.white : textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (icon != null)
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? const Color(0xFF60A5FA) : textMuted,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? textBright : textMuted,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
