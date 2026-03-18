import 'package:flutter/material.dart';
import '../main.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<double>? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 16,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return GestureDetector(
          onTap: interactive && onRatingChanged != null
              ? () => onRatingChanged!(i + 1.0)
              : null,
          child: Icon(
            filled
                ? Icons.star_rounded
                : half
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: AppTheme.star,
          ),
        );
      }),
    );
  }
}

/// Interactive star picker (for review form)
class StarPicker extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onChanged;

  const StarPicker({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<StarPicker> createState() => _StarPickerState();
}

class _StarPickerState extends State<StarPicker> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < _value;
        return GestureDetector(
          onTap: () {
            setState(() => _value = i + 1.0);
            widget.onChanged(_value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 36,
              color: AppTheme.star,
            ),
          ),
        );
      }),
    );
  }
}