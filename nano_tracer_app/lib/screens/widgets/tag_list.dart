import 'package:flutter/material.dart';
import '../../models/tracker_tag.dart';
import 'tag_tile.dart';

class TagList extends StatelessWidget {
  final List<TrackerTag> tags;
  final VoidCallback onRefresh;

  const TagList({super.key, required this.tags, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tags.length,
      itemBuilder: (context, index) {
        return TagTile(
          tag: tags[index],
          onRefresh: onRefresh,
        );
      },
    );
  }
}