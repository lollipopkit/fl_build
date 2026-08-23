import 'dart:convert';
import 'dart:io';

final envFile = Platform.environment['GITHUB_ENV'];
final isGithubAction = envFile != null;

const MORE_BUILD_DATA_PATH = 'more_build_data.json';
const JSON_ENCODER = JsonEncoder.withIndent('  ');
const LINUX_APP_DIR = 'linux.AppDir';
const APK_DIR = 'build/app/outputs/flutter-apk/';
const XCODE_CFG_PATH = 'Runner.xcodeproj/project.pbxproj';
const SHELL_SCRIPT_PATH = 'lib/data/model/app/shell_func.dart';

/// Upstream, rather than the mirror on `cdn.lpkt.cn` these used to come from.
///
/// A release build fetching its packaging tools from a host with no published
/// provenance is a link nobody outside the project can check. Both files are
/// pinned to a tagged release rather than `continuous`, which moves.
///
/// The two live in different repositories, so there is no shared base URL to
/// join a filename onto.
///
/// appimagetool 1.9.1 is not the build the mirror served — that one was an
/// unlabelled `continuous` snapshot (14529264 bytes,
/// `74ab880849bb17d7b4e97c76c22cf9c8ecb0a06435985fda0049311f08eeebf7`) with no
/// tagged equivalent, so this is a version change and the Linux artifact is
/// worth checking once.
const APPIMAGE_TOOL_URL =
    'https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage';

/// The runtime is byte-identical to what the mirror served —
/// `7bde325526367200be59039cafd179a5177fbef36c25a4a75471da5e472568cd`, 651680
/// bytes — so this changes where it comes from and nothing else.
///
/// The tag really is called `old`: `runtime-fuse3-x86_64` was the last name
/// this file had. Current releases publish `runtime-x86_64` (944632 bytes),
/// which is a different binary and would be a change of its own.
const APPIMAGE_RUNTIME_URL =
    'https://github.com/AppImage/type2-runtime/releases/download/old/runtime-fuse3-x86_64';

const APPIMAGE_FILE = '/usr/bin/appimagetool';
const APPIMAGE_RUNTIME_DIR = '/usr/share/appimagetool';
const APPIMAGE_RUNTIME_FILE = '$APPIMAGE_RUNTIME_DIR/runtime-fuse3-x86_64';

final REG_APPLE_VER = RegExp(r'CURRENT_PROJECT_VERSION = .+;');
final REG_APPLE_MARKET_VER = RegExp(r'MARKETING_VERSION = .+');
final REG_PUB_VER = RegExp(r'version: (\d+\.\d+\.\d+)\+?(\d*)');

const RED = '\x1B[31m';
const GREEN = '\x1B[32m';
const BLUE = '\x1B[34m';
const MEGENTA = '\x1B[35m';
const RESET = '\x1B[0m';

/// println
void printColor(String msg, String color) {
  if (stdout.hasTerminal) {
    stdout.write(color);
    stdout.write(msg);
    stdout.writeln(RESET);
  } else {
    stdout.writeln(msg);
  }
}

void printRed(String message) {
  printColor(message, RED);
}

void printGreen(String message) {
  printColor(message, GREEN);
}

void printBlue(String message) {
  printColor(message, BLUE);
}

void printMegenta(String message) {
  printColor(message, MEGENTA);
}
