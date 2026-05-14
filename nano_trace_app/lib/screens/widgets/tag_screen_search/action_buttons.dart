import 'package:flutter/material.dart';

class SearchActionButtons extends StatelessWidget {
  final bool isBipping;
  final VoidCallback onExitSearch;
  final VoidCallback onBip;

  const SearchActionButtons({
    super.key,
    required this.isBipping,
    required this.onExitSearch,
    required this.onBip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: "Stop Search",
            icon: Icons.search_off_rounded,
            color: Colors.grey[700]!,
            backgroundColor: Colors.white,
            onTap: onExitSearch,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _ActionButton(
            label: isBipping ? "Beeping..." : "Beep Tag",
            icon: isBipping
                ? Icons.volume_up_rounded
                : Icons.notifications_active_outlined,
            color: Colors.white,
            backgroundColor: isBipping ? Colors.orange : Colors.teal,
            onTap: isBipping ? null : onBip,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: backgroundColor == Colors.white
                ? Colors.black.withValues(alpha: 0.06)
                : backgroundColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.3,
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
