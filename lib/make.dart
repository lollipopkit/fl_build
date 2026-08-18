import 'dart:io';

import 'package:fl_build/cfg/config.dart';
import 'package:fl_build/target.dart';
import 'package:fl_build/res.dart';
import 'package:fl_build/utils.dart';

final class MakeResult {
  final List<String> pkgPath;

  MakeResult({required this.pkgPath});
}

abstract final class Maker {
  static Future<MakeResult?> run(Target target, {List<String> passthroughArgs = const []}) async {
    switch (target) {
      case Target.android:
        return await flutterBuildAndroid(passthroughArgs: passthroughArgs);
      case Target.ios:
        return await flutterBuildIOS(passthroughArgs: passthroughArgs);
      case Target.mac:
        return await flutterBuildMacOS(passthroughArgs: passthroughArgs);
      case Target.win:
        return await flutterBuildWin(passthroughArgs: passthroughArgs);
      case Target.linux:
        return await flutterBuildLinux(passthroughArgs: passthroughArgs);
      default:
        throw ArgumentError('Unsupported target: $target');
    }
  }

  static Future<void> _flutterBuild(
    String buildType, {
    List<String>? customArgs,
    List<String> passthroughArgs = const [],
  }) async {
    final setup = makeCfg.platformSetup.entries
        .firstWhereOrNull((e) => e.key == buildType)
        ?.value;
    if (setup != null) {
      printBlue('Platform setup...');
      final result = await Process.run('sh', ['-c', setup]);
      if (result.exitCode != 0) {
        print(result.stderr);
        exit(1);
      }
    }

    final makeCfgArgs = makeCfg.customArgs.entries
        .firstWhereOrNull((e) => e.key == buildType)
        ?.value;
    final args = [
      'build',
      buildType,
      '--build-number=$buildDataVersion',
      '--build-name=1.0.$buildDataVersion',
       ...?customArgs,
       ...?makeCfgArgs,
      ...passthroughArgs,
    ];

    print('\n[$buildType]\nflutter ${args.join(' ')}');

    final buildResult = await Process.run('flutter', args, runInShell: true);
    final exitCode = buildResult.exitCode;
    if (exitCode != 0) {
      print(buildResult.stdout);
      print(buildResult.stderr);
      exit(exitCode);
    }
  }

  static Future<MakeResult?> flutterBuildIOS({List<String> passthroughArgs = const []}) async {
    await _flutterBuild('ipa', passthroughArgs: passthroughArgs);
    return null;
  }

  static Future<MakeResult?> flutterBuildMacOS({List<String> passthroughArgs = const []}) async {
    await _flutterBuild('macos', passthroughArgs: passthroughArgs);
    return null;
  }

  static Future<MakeResult?> flutterBuildAndroid({List<String> passthroughArgs = const []}) async {
    await _flutterBuild('apk', customArgs: ['--split-per-abi'], passthroughArgs: passthroughArgs);

    // {originName: newName}
    final namesMap = {
      'app-arm64-v8a-release.apk': '${appName}_${buildDataVersion}_arm64.apk',
      'app-armeabi-v7a-release.apk': '${appName}_${buildDataVersion}_arm.apk',
      'app-x86_64-release.apk': '${appName}_${buildDataVersion}_amd64.apk',
    };
    for (final entry in namesMap.entries) {
      final origin = entry.key;
      final newName = entry.value;
      // Use copy, so that the shell history will only retain the record `adb
      // install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
      await File('$APK_DIR$origin').copy('$APK_DIR$newName');
    }

    return MakeResult(
      pkgPath: namesMap.values.map((e) => '$APK_DIR$e').toList(),
    );
  }

  static Future<MakeResult?> flutterBuildLinux({List<String> passthroughArgs = const []}) async {
    await installLinuxEnv();
    await setupLinuxDir();
    await _flutterBuild('linux', passthroughArgs: passthroughArgs);
    // cp -r build/linux/x64/release/bundle/* appName.AppDir
    await Process.run('cp', [
      '-r',
      'build/linux/x64/release/bundle',
      LINUX_APP_DIR,
    ]);
    // Run appimagetool
    final appimg = await Process.run(
      'appimagetool',
      [
        LINUX_APP_DIR,
        '--runtime-file',
        APPIMAGE_RUNTIME_FILE,
      ],
      environment: {'ARCH': 'x86_64'},
    );
    if (appimg.exitCode != 0) {
      print(appimg.stdout);
      print(appimg.stderr);
      exit(appimg.exitCode);
    }

    final pkgPath = '${appName}_${buildDataVersion}_amd64.AppImage';
    await File('$appName-x86_64.AppImage').rename(pkgPath);
    return MakeResult(pkgPath: [pkgPath]);
  }

  static Future<MakeResult?> flutterBuildWin({List<String> passthroughArgs = const []}) async {
    await _flutterBuild('windows', passthroughArgs: passthroughArgs);

    final pkgPath = '${appName}_${buildDataVersion}_windows_amd64.zip';
    final buildPath = 'build\\windows\\x64\\runner\\Release\\*';

    //print("Creating zip archive to $pkgPath ...");

    final result = await Process.run('powershell', [
      'Compress-Archive',
      '-Path',
      buildPath,
      '-DestinationPath',
      pkgPath,
      '-Force'
    ]);

    //print("Archive creator returned with code: ${result.exitCode}");
    if (result.exitCode != 0) {
      print(result.stdout);
      print(result.stderr);
      return MakeResult(pkgPath: []);
    }

    return MakeResult(pkgPath: [pkgPath]);
  }
}
