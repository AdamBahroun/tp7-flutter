import 'dart:io';
import 'package:flutter/foundation.dart';

String get baseUrl {
  const env = String.fromEnvironment('TP7_BASE_URL');
  if (env.isNotEmpty) return env;
  if (kIsWeb) return 'http://localhost:8081';
  if (Platform.isAndroid) return 'http://10.0.2.2:8081';
  return 'http://172.20.10.12:8081';
}
