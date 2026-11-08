import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 3),
  responseDataCallback: (data) => writeResponseData(
    data,
    testOutputFilename:
        '${data?['platform'] ?? 'device'}-${data?['buildMode'] ?? 'integration'}',
    destinationDirectory:
        Platform.environment['MOABOOK_QA_OUTPUT'] ??
        'build/integration_results',
  ),
);
