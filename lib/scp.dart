import 'dart:io';

import 'package:fl_build/cfg/config.dart';
import 'package:fl_build/res.dart';
import 'package:fl_build/target.dart';

const SCP_PATH = String.fromEnvironment('FLBUILD_SCP_PATH', defaultValue: 'hskb:/var/www/res/');

abstract final class Scps {
  static const supportedTargets = [Target.android, Target.linux, Target.win];

  static Future<void> run(Target target, String relPath) async {
    if (!supportedTargets.contains(target)) {
      printRed('Unsupported target: $target');
      return;
    }
    await _scp(relPath);
  }

  static Future<void> _scp(String relPath) async {
    final name = relPath.split('/').last;
    final result = await Process.run(
      'scp',
      [relPath, '$SCP_PATH$appNameLower/pkg/$name'],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      print(result.stderr);
      exit(1);
    }
    printGreen('Upload $name finished.');
  }
}
