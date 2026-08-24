#!/usr/bin/env dart
// ignore_for_file: avoid_print, non_constant_identifier_names, constant_identifier_names

import 'dart:io';

import 'package:fl_build/cfg/config.dart';
import 'package:fl_build/make.dart';
import 'package:fl_build/res.dart';
import 'package:fl_build/scp.dart';
import 'package:fl_build/target.dart';
import 'package:fl_build/utils.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  final params = <String, String?>{};
  List<String> passthroughArgs = [];
  
  // Find the -- separator to split args
  final separatorIndex = args.indexOf('--');
  final mainArgs = separatorIndex >= 0 ? args.take(separatorIndex).toList() : args;
  if (separatorIndex >= 0) {
    passthroughArgs = args.skip(separatorIndex + 1).toList();
  }
  
  for (var i = 0; i < mainArgs.length;) {
    final arg = mainArgs[i];
    if (arg.startsWith('-')) {
      if (i + 1 < mainArgs.length && !mainArgs[i + 1].startsWith('-')) {
        params[arg] = mainArgs[i + 1];
        i += 2;
      } else {
        params[arg] = null;
        i++;
      }
    } else {
      printMegenta('Invalid: $arg');
    }
  }

  makeCfg = await _loadCfg();

  // Before build
  final beforeBuild = makeCfg.beforeBuild;
  if (beforeBuild != null) {
    printBlue('Before build...');
    final result = await Process.run('sh', ['-c', beforeBuild]);
    if (result.exitCode != 0) {
      print(result.stderr);
      exit(1);
    }
  }

  // If [forRelease] is true, it will run all the preparation steps.
  final buildPreparation =
      params.containsKey('-bp') || params.containsKey('-r');
  if (buildPreparation) {
    await updateBuildData(); // Put it at first
    await changePubVersion();
    await changeAppleVersion();
  }

  final forRelease = params.containsKey('-r');
  if (forRelease) {
    await gitSubmmit();
  }

  // If it's running in Github Actions, it will setup the environment.
  await setupGithubEnv();

  // Build
  final platforms = params['-p']?.split(',');
  final scp = params.containsKey('-s') || params.containsKey('--scp');

  if (platforms == null) {
    printRed('No platform specified. Exit.');
    return;
  }

  for (final platform in platforms) {
    final target = Target.fromString(platform);
    final res = await Maker.run(target, passthroughArgs: passthroughArgs);
    if (res == null) continue;
    for (final path in res.pkgPath) {
      if (scp) await Scps.run(target, path);
    }
  }

  // After build
  final afterBuild = makeCfg.afterBuild;
  if (afterBuild != null) {
    printBlue('After build...');
    final result = await Process.run('sh', ['-c', afterBuild]);
    if (result.exitCode != 0) {
      print(result.stderr);
      exit(1);
    }
  }
}

/// The build config: the `fl_build:` section of `pubspec.yaml`.
///
/// One place, and one this project already has. It was a `fl_build.json` of
/// its own, which for most projects is a file carrying a single app name — and
/// a second file is a second thing to keep level with the first, since the
/// pubspec is where the version and the assets are declared anyway.
Future<MakeCfg> _loadCfg() async {
  final pubspec = File('pubspec.yaml');
  if (await pubspec.exists()) {
    final doc = loadYaml(await pubspec.readAsString());
    final section = doc is YamlMap ? doc['fl_build'] : null;
    if (section is YamlMap) return MakeCfg.fromJson(_plain(section));
  }

  printMegenta(
    'No build config: pubspec.yaml needs an `fl_build:` section, with at '
    'least `appName`.',
  );
  exit(1);
}

/// A YAML subtree as the plain maps and lists the generated decoder wants.
///
/// `YamlMap` is a `Map` and `YamlList` is a `List`, so the outer cast would
/// pass and the first nested value would then fail one — which reads as the
/// config being malformed rather than as the wrong kind of map.
Map<String, dynamic> _plain(YamlMap map) {
  Object? value(Object? node) => switch (node) {
    YamlMap map => _plain(map),
    YamlList list => [for (final item in list) value(item)],
    _ => node,
  };
  return {for (final e in map.entries) e.key.toString(): value(e.value)};
}
