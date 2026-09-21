import 'package:flutter/material.dart';
import '../../models/fps/fps_models.dart';

/// 12-Item Government Navigation Sidebar for Fair Price Shop Owner Portal
class FpsSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final FpsOwnerProfile? profile;

  const FpsSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.profile,
  });

  static const Color _navDark = Color(0xFF0A192F);
  static const Color _navHover = Color(0xFF172A45);
  static const Color _navActive = Color(0xFF1E3A8A);
  static const Color _accentCyan = Color(0xFF38BDF8);

  static const List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'code': '01'},
    {'icon': Icons.store_rounded, 'label': 'My FPS', 'code': '02'},
    {'icon': Icons.inventory_2_rounded, 'label': 'Stock & Inventory', 'code': '03'},
    {'icon': Icons.local_shipping_rounded, 'label': 'Incoming Deliveries', 'code': '04'},
    {'icon': Icons.point_of_sale_rounded, 'label': 'e-PoS Distribution', 'code': '05'},
    {'icon': Icons.people_alt_rounded, 'label': 'Beneficiary Records', 'code': '06'},
    {'icon': Icons.receipt_long_rounded, 'label': 'Transactions', 'code': '07'},
    {'icon': Icons.analytics_rounded, 'label': 'Reports', 'code': '08'},
    {'icon': Icons.psychology_rounded, 'label': 'AI Insights', 'code': '09'},
    {'icon': Icons.warning_amber_rounded, 'label': 'Exceptions', 'code': '10'},
    {'icon': Icons.history_edu_rounded, 'label': 'Decision Trace', 'code': '11'},
    {'icon': Icons.storage_rounded, 'label': 'Data Sources', 'code': '12'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: _navDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _navActive,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accentCyan.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'PDS DemandSync',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'FPS Operations Portal',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Nav Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: _navHover,
                      onTap: () => onItemSelected(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? _navActive : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: _accentCyan.withOpacity(0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Text(
                              item['code'],
                              style: TextStyle(
                                color: isSelected ? _accentCyan : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              item['icon'] as IconData,
                              size: 18,
                              color: isSelected ? Colors.white : Colors.white60,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _accentCyan,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Bottom FPS Badge
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _navActive,
                    child: const Icon(Icons.storefront_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Fair Price Shop',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          profile?.fpsId ?? 'FPS-KA-BLR-002',
                          style: const TextStyle(
                            color: _accentCyan,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
