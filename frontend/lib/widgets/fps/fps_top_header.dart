import 'package:flutter/material.dart';
import '../../models/fps/fps_models.dart';

/// Desktop Top Header for Fair Price Shop Command Center
class FpsTopHeader extends StatelessWidget {
  final FpsOwnerProfile? profile;
  final String activeCycle;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final VoidCallback onOpenShop;
  final VoidCallback onCloseShop;
  final bool isActionLoading;

  const FpsTopHeader({
    super.key,
    required this.profile,
    required this.activeCycle,
    required this.onRefresh,
    required this.onLogout,
    required this.onOpenShop,
    required this.onCloseShop,
    this.isActionLoading = false,
  });

  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF16A34A);
  static const Color _govAmber = Color(0xFFD97706);
  static const Color _govRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final isOpen = profile?.operatingStatus == 'OPEN';

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Title & Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'FAIR PRICE SHOP COMMAND CENTER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _govNavy,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${profile?.district ?? "Bengaluru Urban"} District • Public Distribution System Operations',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Operating Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOpen ? Colors.green.shade300 : Colors.red.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOpen ? _govGreen : _govRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOpen ? 'SHOP OPERATIONAL' : 'SHOP CLOSED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOpen ? _govGreen : _govRed,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Active Cycle Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded, size: 14, color: Colors.blue.shade800),
                const SizedBox(width: 6),
                Text(
                  'Cycle: $activeCycle',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Quick Operational Action: Open / Close Shop
          if (isOpen)
            OutlinedButton.icon(
              onPressed: isActionLoading ? null : onCloseShop,
              icon: const Icon(Icons.lock_clock_rounded, size: 16, color: _govRed),
              label: const Text('Close Daily Ledger', style: TextStyle(color: _govRed, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: isActionLoading ? null : onOpenShop,
              icon: const Icon(Icons.store_rounded, size: 16, color: Colors.white),
              label: const Text('Open Shop', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _govGreen,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),

          const SizedBox(width: 12),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: _govNavy),
            tooltip: 'Refresh Real Database State',
            onPressed: onRefresh,
          ),

          const SizedBox(width: 8),

          // Profile & Logout
          PopupMenuButton<String>(
            tooltip: 'FPS Operator Account',
            onSelected: (val) {
              if (val == 'logout') onLogout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.dealerName ?? 'Authorized Dealer',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      profile?.fpsId ?? 'FPS-KA-BLR-002',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: _govRed),
                    SizedBox(width: 8),
                    Text('Secure Sign Out', style: TextStyle(color: _govRed, fontSize: 13)),
                  ],
                ),
              ),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _govNavy,
                  child: Text(
                    (profile?.authenticatedUser.isNotEmpty == true ? profile!.authenticatedUser[0].toUpperCase() : 'F'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down, color: _govNavy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
