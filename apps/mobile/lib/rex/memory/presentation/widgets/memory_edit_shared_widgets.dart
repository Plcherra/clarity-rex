import 'package:flutter/material.dart';

String? nullableEditText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class MemoryEditImportanceSlider extends StatelessWidget {
  const MemoryEditImportanceSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        Text(value.round().toString()),
      ],
    );
  }
}
