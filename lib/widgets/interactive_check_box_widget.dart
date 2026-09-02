import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/check_item_model.dart';

/// An interactive, animated checkmark widget placed directly on journal/planner canvases.
/// Provides satisfying tactile haptic feedback and fluid bounce animation upon single-tap.
class InteractiveCheckBoxWidget extends StatefulWidget {
  final InteractiveCheckItem item;
  final bool isBuilderPreview;
  final bool isSelected;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  const InteractiveCheckBoxWidget({
    super.key,
    required this.item,
    this.isBuilderPreview = false,
    this.isSelected = false,
    this.onToggle,
    this.onTap,
  });

  @override
  State<InteractiveCheckBoxWidget> createState() => _InteractiveCheckBoxWidgetState();
}

class _InteractiveCheckBoxWidgetState extends State<InteractiveCheckBoxWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.elasticIn)), weight: 50),
    ]).animate(_animController);

    if (widget.item.isChecked) {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveCheckBoxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.isChecked != widget.item.isChecked) {
      if (widget.item.isChecked) {
        _animController.forward(from: 0.0);
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isBuilderPreview) {
      widget.onTap?.call();
      return;
    }

    HapticFeedback.lightImpact();
    widget.onToggle?.call();
  }

  Widget _buildCheckContent() {
    final shape = widget.item.shape;
    final isChecked = widget.item.isChecked;
    final color = widget.item.checkColor;

    if (!isChecked && !widget.isBuilderPreview) {
      // Clean, seamless target area so the printed template artwork shows through
      return Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(shape == CheckboxShape.circle ? 99 : 4),
        ),
      );
    }

    if (widget.isBuilderPreview) {
      // In builder preview, show a clear badge so the user sees detected checkpoint spots
      return Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: widget.isSelected ? 0.45 : 0.22),
          borderRadius: BorderRadius.circular(shape == CheckboxShape.circle ? 99 : 4),
          border: Border.all(
            color: widget.isSelected ? Colors.white : color,
            width: widget.isSelected ? 2.0 : 1.2,
          ),
          boxShadow: [
            if (widget.isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Center(
          child: Icon(
            _getShapeIcon(shape),
            size: 14,
            color: widget.isSelected ? Colors.white : color,
          ),
        ),
      );
    }

    // Active Checked State in Journal Editor
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: shape == CheckboxShape.circle
              ? color
              : color.withValues(alpha: 0.15),
          shape: shape == CheckboxShape.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: shape == CheckboxShape.circle ? null : BorderRadius.circular(4),
          border: shape == CheckboxShape.circle
              ? null
              : Border.all(color: color, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            shape == CheckboxShape.circle
                ? Icons.check_rounded
                : (shape == CheckboxShape.water ? Icons.water_drop_rounded : Icons.check_rounded),
            color: shape == CheckboxShape.circle ? Colors.white : color,
            size: 16,
          ),
        ),
      ),
    );
  }

  IconData _getShapeIcon(CheckboxShape shape) {
    switch (shape) {
      case CheckboxShape.square:
        return Icons.check_box_outlined;
      case CheckboxShape.circle:
        return Icons.radio_button_unchecked_rounded;
      case CheckboxShape.water:
        return Icons.water_drop_outlined;
      case CheckboxShape.star:
        return Icons.star_border_rounded;
      case CheckboxShape.heart:
        return Icons.favorite_border_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: _buildCheckContent(),
    );
  }
}
