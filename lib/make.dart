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
    final apkDir = Directory(APK_DIR);
    if (await apkDir.exists()) {
      await for (final entity in apkDir.list()) {
        if (entity is File && entity.path.endsWith('.apk')) await entity.delete();
      }
    }
    await _flutterBuild('apk', customArgs: ['--split-per-abi'], passthroughArgs: passthroughArgs);

    final abiNames = {
      'arm64-v8a': '${appName}_${buildDataVersion}_arm64.apk',
      'armeabi-v7a': '${appName}_${buildDataVersion}_arm.apk',
      'x86_64': '${appName}_${buildDataVersion}_amd64.apk',
    };
    final generated = (await apkDir.list().toList()).where((entity) {
      if (entity is! File || !entity.path.endsWith('.apk')) return false;
      final name = entity.uri.pathSegments.last;
      return abiNames.keys.any((abi) => name.contains('-$abi-'));
    });
    final pkgPaths = <String>[];
    for (final entity in generated) {
      final file = entity as File;
      final name = file.uri.pathSegments.last;
      final abi = abiNames.keys.firstWhere((abi) => name.contains('-$abi-'));
      final newName = abiNames[abi]!;
      // Use copy, so that the shell history will only retain the record `adb
      // install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
      final path = '$APK_DIR$newName';
      await file.copy(path);
      pkgPaths.add(path);
    }
    if (pkgPaths.isEmpty) throw StateError('No split APKs were generated.');

    return MakeResult(pkgPath: pkgPaths);
  }

  static Future<MakeResult?> flutterBuildLinux({List<String> passthroughArgs = const []}) async {
    if (!Platform.isLinux) throw UnsupportedError('Linux builds require a Linux host.');
    await installLinuxEnv();
    await setupLinuxDir();
    await _flutterBuild('linux', passthroughArgs: passthroughArgs);
    // The bundle's *contents* go to the AppDir root, so the executable sits
    // beside `AppRun` and the `.desktop` file's `Exec=<appName>` names
    // something that is actually there.
    //
    // `bundle/.` rather than `bundle/*`, which is what the comment here used to
    // say: `Process.run` starts `cp` directly, with no shell to expand a glob,
    // so `*` would have been a literal path. Dropping it made the copy work and
    // nested the whole bundle one level down instead.
    final copy = await Process.run('cp', [
      '-r',
      'build/linux/x64/release/bundle/.',
      LINUX_APP_DIR,
    ]);
    if (copy.exitCode != 0) {
      print(copy.stderr);
      exit(copy.exitCode);
    }
    // Run appimagetool
    final pkgPath = '${appName}_${buildDataVersion}_amd64.AppImage';
    final appimg = await Process.run(
      'appimagetool',
      [
        LINUX_APP_DIR,
        pkgPath,
        '--runtime-file',
        APPIMAGE_RUNTIME_FILE,
      ],
      environment: {...Platform.environment, 'ARCH': 'x86_64'},
    );
    if (appimg.exitCode != 0) {
      print(appimg.stdout);
      print(appimg.stderr);
      exit(appimg.exitCode);
    }

    return MakeResult(pkgPath: [pkgPath]);
  }

  static Future<MakeResult?> flutterBuildWin({List<String> passthroughArgs = const []}) async {
    await _flutterBuild('windows', passthroughArgs: passthroughArgs);

    final pkgPath = '${appName}_${buildDataVersion}_windows_amd64.zip';
    final tempPath = '$pkgPath.$pid.tmp.zip';
    final buildPath = 'build\\windows\\x64\\runner\\Release\\*';

    //print("Creating zip archive to $pkgPath ...");

    final result = await Process.run('powershell', [
      'Compress-Archive',
      '-Path',
      buildPath,
      '-DestinationPath',
      tempPath,
    ]);

    //print("Archive creator returned with code: ${result.exitCode}");
    if (result.exitCode != 0) {
      print(result.stdout);
      print(result.stderr);
      exit(result.exitCode);
    }
    try {
      await File(tempPath).rename(pkgPath);
    } on FileSystemException catch (e) {
      print(e);
      exit(1);
    }

    return MakeResult(pkgPath: [pkgPath]);
  }
}
