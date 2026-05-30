import 'package:flutter/foundation.dart';

void main() {
  const key = String.fromEnvironment('ANDROID_DRIVE_KEY');

  debugPrint('Key is: "$key"');
  debugPrint('Key is empty? ${key.isEmpty}');
}
