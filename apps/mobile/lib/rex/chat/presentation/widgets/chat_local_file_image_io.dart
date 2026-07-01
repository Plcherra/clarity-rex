import 'dart:io';

import 'package:flutter/material.dart';

Widget buildChatLocalFileImage({
  required String path,
  required BoxFit fit,
  double? width,
  double? maxHeight,
  required FilterQuality filterQuality,
}) {
  return Image.file(
    File(path),
    fit: fit,
    width: width,
    height: maxHeight,
    filterQuality: filterQuality,
  );
}
