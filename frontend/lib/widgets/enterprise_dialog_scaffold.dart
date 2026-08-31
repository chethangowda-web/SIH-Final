import 'package:flutter/material.dart';
import '../core/constants.dart';

class EnterpriseDialogScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final IconData headerIcon;
  final Color? headerIconColor;
  final Color? headerIconBg;
  final Widget body;
  final Widget? footerLeft;
  final List<Widget>? footerActions;
  final PreferredSizeWidget? bottomHeader;
  final double maxWidth;
  final double maxHeight;
  final VoidCallback? onRefresh;

  const EnterpriseDialogScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.headerIcon,
    this.headerIconColor,
    this.headerIconBg,
    required this.body,
    this.footerLeft,
    this.footerActions,
    this.bottomHeader,
    this.maxWidth = 920.0,
    this.maxHeight = 850.0,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final effectiveMaxWidth = maxWidth.clamp(320.0, screenSize.width * 0.94);
    final effectiveMaxHeight = maxHeight.clamp(300.0, screenSize.height * 0.92);

    final iconColor = headerIconColor ?? Colors.white;
    final iconBg = headerIconBg ?? Colors.white.withValues(alpha: 0.15);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: effectiveMaxWidth,
          height: effectiveMaxHeight,
          decoration: BoxDecoration(
            color: AppConstants.cardSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppConstants.cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Enterprise Top Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.space20,
                    vertical: AppConstants.space16,
                  ),
                  color: AppConstants.primaryNavy,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(headerIcon, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (badgeText != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (badgeColor ?? AppConstants.accentAmber)
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: badgeColor ?? AppConstants.accentAmber,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          badgeText!,
                                          style: TextStyle(
                                            color: badgeColor ?? AppConstants.accentAmber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (onRefresh != null) ...[
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                              tooltip: 'Refresh Data',
                              onPressed: onRefresh,
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            tooltip: 'Close Modal',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      if (bottomHeader != null) ...[
                        const SizedBox(height: 8),
                        bottomHeader!,
                      ],
                    ],
                  ),
                ),

                // 2. Scrollable Body Content
                Expanded(
                  child: Container(
                    color: AppConstants.backgroundLight,
                    child: body,
                  ),
                ),

                // 3. Optional Sticky Footer Action Strip
                if (footerActions != null || footerLeft != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.space20,
                      vertical: AppConstants.space12,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.cardSurface,
                      border: Border(
                        top: BorderSide(color: AppConstants.cardBorder, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (footerLeft != null)
                          Expanded(child: footerLeft!)
                        else
                          const SizedBox.shrink(),
                        if (footerActions != null)
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            children: footerActions!,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
