import 'package:flutter/material.dart';
import '../core/constants.dart';

class WorkflowStepper extends StatelessWidget {
  final String currentWorkflowStatus;
  final Function(int stepIndex) onStepSelected;

  const WorkflowStepper({
    super.key,
    required this.currentWorkflowStatus,
    required this.onStepSelected,
  });

  int _getActiveStepIndex() {
    switch (currentWorkflowStatus.toUpperCase()) {
      case 'PLANNING_OPEN':
        return 0; // 01 Forecast
      case 'DRAFT_GENERATED':
        return 1; // 02 Lock Forecast
      case 'FORECAST_LOCKED':
        return 2; // 03 Constraints
      case 'CONSTRAINTS_VALIDATED':
        return 3; // 04 Optimization
      case 'ROUTE_OPTIMIZED':
        return 4; // 05 Manifest
      case 'MANIFEST_LOCKED':
      case 'DISPATCH_GENERATED':
        return 5; // 06 Gatepass
      case 'GATEPASS_ISSUED':
      case 'DISPATCHED':
        return 6; // 07 Dispatch
      case 'DISTRIBUTED':
      case 'EVALUATED':
      case 'COMPLETED':
        return 7; // 08 Evaluation
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _getActiveStepIndex();
    final steps = AppConstants.workflowSteps;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16, vertical: AppConstants.space12),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;

          if (isCompact) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildStepItems(steps, activeIndex),
              ),
            );
          }

          return Row(
            children: _buildStepItems(steps, activeIndex),
          );
        },
      ),
    );
  }

  List<Widget> _buildStepItems(List<Map<String, String>> steps, int activeIndex) {
    List<Widget> items = [];

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final isCompleted = i < activeIndex;
      final isCurrent = i == activeIndex;

      items.add(
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: () => onStepSelected(i),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppConstants.space8, horizontal: AppConstants.space8),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppConstants.primaryNavy.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: isCurrent
                    ? Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.4), width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step Indicator Circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppConstants.successGreen
                          : (isCurrent ? AppConstants.primaryNavy : const Color(0xFFF1F5F9)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? AppConstants.successGreen
                            : (isCurrent ? AppConstants.primaryNavy : AppConstants.cardBorder),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                          : Text(
                              step['num'] ?? '${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isCurrent ? Colors.white : AppConstants.textSecondary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.space8),

                  // Step Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          step['title'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.w800 : (isCompleted ? FontWeight.w600 : FontWeight.w500),
                            color: isCurrent
                                ? AppConstants.primaryNavy
                                : (isCompleted ? AppConstants.textPrimary : AppConstants.textTertiary),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isCompleted ? 'Completed' : (isCurrent ? 'Active Stage' : 'Pending'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isCompleted
                                ? AppConstants.successGreen
                                : (isCurrent ? AppConstants.accentBlue : AppConstants.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Connector line between steps (except last)
      if (i < steps.length - 1) {
        items.add(
          Container(
            width: 12,
            height: 1.5,
            color: i < activeIndex ? AppConstants.successGreen.withValues(alpha: 0.6) : AppConstants.cardBorder,
            margin: const EdgeInsets.symmetric(horizontal: 2),
          ),
        );
      }
    }

    return items;
  }
}
