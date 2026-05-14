import 'package:flutter/material.dart';
import 'package:nano_trace_app/screens/widgets/shared/info_card.dart';
import 'package:nano_trace_app/screens/widgets/shared/search_mode_card.dart';
import 'package:nano_trace_app/screens/widgets/tag_screen_normal/battery_level.dart';
import 'package:nano_trace_app/screens/widgets/tag_screen_normal/radar_view.dart';
import 'package:nano_trace_app/screens/widgets/tag_screen_normal/status_card.dart';
import 'package:nano_trace_app/services/distance_service.dart';

class NormalModeLayout extends StatelessWidget {
  final AnimationController controller;
  final bool tagNearby;
  final DistanceRange range;
  final int battLevel;
  final bool isBusy;
  final VoidCallback onToggleSearch;

  const NormalModeLayout({
    super.key,
    required this.controller,
    required this.tagNearby,
    required this.range,
    required this.battLevel,
    required this.isBusy,
    required this.onToggleSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              RadarView(
                animation: controller,
                isConnected: tagNearby,
                distanceRange: range,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: InfoCard(
                        child: batteryLevel(
                          battLevel >= 0 ? battLevel / 4.0 : 0.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: InfoCard(
                        child: StatusCard(isConnected: tagNearby),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SearchModeCard(
          isActive: false,
          isTagNearby: tagNearby,
          isBusy: isBusy,
          onToggle: onToggleSearch,
        ),
      ],
    );
  }
}
