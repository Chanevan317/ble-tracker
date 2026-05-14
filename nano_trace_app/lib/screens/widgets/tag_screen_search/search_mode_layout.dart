import 'package:flutter/material.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';
import 'package:nano_trace_app/screens/widgets/tag_screen_search/action_buttons.dart';
import 'package:nano_trace_app/screens/widgets/tag_screen_search/direction_compass.dart';
import 'package:nano_trace_app/screens/widgets/tag_screen_search/distance_indicator.dart';
import 'package:nano_trace_app/services/distance_service.dart';

class SearchModeLayout extends StatelessWidget {
  final TrackerTag tag;
  final DistanceRange range;
  final bool tagNearby;
  final double directionAngle;
  final bool isBipping;
  final VoidCallback onExitSearch;
  final VoidCallback onBip;

  const SearchModeLayout({
    super.key,
    required this.tag,
    required this.range,
    required this.tagNearby,
    required this.directionAngle,
    required this.isBipping,
    required this.onExitSearch,
    required this.onBip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: DirectionCompass(
              angle: directionAngle,
              tagNearby: tagNearby,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DistanceIndicator(range: range, tagNearby: tagNearby),
        const SizedBox(height: 16),
        SearchActionButtons(
          isBipping: isBipping,
          onExitSearch: onExitSearch,
          onBip: onBip,
        ),
      ],
    );
  }
}
