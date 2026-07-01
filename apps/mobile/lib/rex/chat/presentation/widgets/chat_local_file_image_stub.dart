import 'package:flutter/material.dart';

Widget buildChatLocalFileImage({
  required String path,
  required BoxFit fit,
  double? width,
  double? maxHeight,
  required FilterQuality filterQuality,
}) {
  return SizedBox(
    height: maxHeight ?? 96,
    width: width,
    child: const Center(child: Icon(Icons.image_outlined)),
  );
}
