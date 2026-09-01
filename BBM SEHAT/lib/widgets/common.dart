import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(2, 22, 2, 12)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: AppText.body(size: 11, color: AppColors.mut).copyWith(letterSpacing: 1.4),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final Color valueColor;
  final String label;
  const StatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.valueColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: iconColor),
        const SizedBox(height: 8),
        Text(value, style: AppText.num(size: 22, color: valueColor)),
        const SizedBox(height: 4),
        Text(label, style: AppText.body(size: 10.5, color: AppColors.mut)),
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  final double fontSize;
  final Color borderColor;
  final Color textColor;
  // Optional — every existing call site omits this and keeps showing
  // initials exactly as before. When set, shows the photo instead, falling
  // back to initials if it fails to load (removed/unreachable URL, no
  // network, etc.) rather than a broken-image icon.
  final String? imageUrl;
  const Avatar({
    super.key,
    required this.initials,
    this.size = 36,
    this.fontSize = 13,
    this.borderColor = AppColors.line,
    this.textColor = AppColors.text,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card2,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderColor == AppColors.line ? 1 : 2),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(initials, style: AppText.heading(size: fontSize, color: textColor))
          : Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Text(initials, style: AppText.heading(size: fontSize, color: textColor)),
            ),
    );
  }
}

class PillTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  const PillTag({
    super.key,
    required this.text,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 5)],
        Text(text, style: AppText.body(size: 11, color: color)),
      ]),
    );
  }
}

class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: i == selectedIndex ? AppColors.card2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: AppText.body(
                    size: 12.5,
                    color: i == selectedIndex ? AppColors.accent : AppColors.mut,
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
