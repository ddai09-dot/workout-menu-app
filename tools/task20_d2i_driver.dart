// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

void emitAcceptanceMetadata(Map<String, dynamic>? data) {
  if (data == null) {
    throw StateError('Task20 acceptance responseData is required.');
  }

  final task = data['task'];
  final phase = data['phase'];
  final metadata = data['metadata'];
  if (metadata is! Map) {
    throw StateError('Task20 responseData metadata must be a map.');
  }

  late final String marker;
  if (task == 'Task20-D2I') {
    if (phase != 'PHASE1' && phase != 'PHASE2') {
      throw StateError('Unexpected Task20-D2I responseData phase: $phase');
    }
    marker = 'D2I_${phase}_METADATA';
  } else if (task == 'Task20-D2K') {
    if (phase != 'TRIGGER' && phase != 'VERIFY') {
      throw StateError('Unexpected Task20-D2K responseData phase: $phase');
    }
    marker = 'D2K_${phase}_METADATA';
  } else {
    throw StateError('Unexpected Task20 responseData task: $task');
  }

  const maxChunkLength = 600;
  final encoded = jsonEncode(metadata);
  final totalChunks = (encoded.length + maxChunkLength - 1) ~/ maxChunkLength;
  for (var index = 0; index < totalChunks; index += 1) {
    final start = index * maxChunkLength;
    final end = start + maxChunkLength < encoded.length
        ? start + maxChunkLength
        : encoded.length;
    print(
      '${marker}_CHUNK_${index + 1}_OF_$totalChunks=${encoded.substring(start, end)}',
    );
  }
}

Future<void> main() async {
  final outputDirectory = Platform.environment['TASK20_D2_SCREENSHOT_DIR'];
  if (outputDirectory == null || outputDirectory.isEmpty) {
    throw StateError('TASK20_D2_SCREENSHOT_DIR is required.');
  }
  final directory = Directory(outputDirectory);
  await directory.create(recursive: true);
  final driver = await FlutterDriver.connect();

  await integrationDriver(
    driver: driver,
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
    responseDataCallback: (Map<String, dynamic>? data) async {
      emitAcceptanceMetadata(data);
    },
  );
}
