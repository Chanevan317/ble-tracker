import 'package:flutter/material.dart';

class SearchModeCard extends StatelessWidget {
  final bool isActive;
  final bool isTagNearby;
  final bool isBusy;
  final VoidCallback onToggle;

  const SearchModeCard({
    super.key,
    required this.isActive,
    required this.isTagNearby,
    required this.isBusy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isActive ? Colors.teal : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? Colors.teal.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isActive ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isBusy ? null : onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isActive
                        ? Icons.search_off_rounded
                        : Icons.manage_search_rounded,
                    key: ValueKey(isActive),
                    color: isActive ? Colors.white : Colors.teal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? "Searching..." : "Search Tag",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isActive
                            ? "Tag advertising at 100ms — tap to stop"
                            : "Fast mode for active finding",
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.75)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? Colors.white
                        : (isTagNearby ? Colors.teal : Colors.grey[300]),
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
