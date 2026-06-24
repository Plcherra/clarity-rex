import 'package:flutter/material.dart';

import 'clarity_path_loader.dart';

class ClarityDiamondLoader extends StatelessWidget {
  const ClarityDiamondLoader({super.key, this.size = 92, this.label});

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ClarityPathLoader(size: size, label: label);
  }
}
