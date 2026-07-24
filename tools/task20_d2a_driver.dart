import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final outputDirectory = Platform.environment['TASK20_D2_SCREENSHOT_DIR'];
  if (outputDirectory == null || outputDirectory.isEmpty) {
    throw StateError('TASK20_D2_SCREENSHOT_DIR is required.');
  }
  final directory = Directory(outputDirectory);
  await directory.create(recursive: true);

  await integrationDriver(
    onScreenshot: (
      String name,
      List<int> bytes, [
      Map<String, Object?>? args,
    ]) async {
      final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      final file = File('${directory.path}/$safeName.png');
      await file.writeAsBytes(bytes, flush: true);
      return file.lengthSync() > 0;
    },
  );
}
