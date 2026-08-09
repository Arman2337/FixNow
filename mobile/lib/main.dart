import 'package:flutter/material.dart';
import 'package:fixnow_mobile/app/app.dart';
import 'package:fixnow_mobile/config/app_environment.dart';

void main() {
  runApp(FixNowApp(environment: AppEnvironment.current));
}
