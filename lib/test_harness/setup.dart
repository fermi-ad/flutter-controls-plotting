import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setSmallScreenSize(WidgetTester tester) async =>
    tester.binding.setSurfaceSize(const Size(375, 667));

Future<void> setDesktopScreenSize(WidgetTester tester) async =>
    tester.binding.setSurfaceSize(const Size(1024, 768));
