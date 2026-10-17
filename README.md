## fl_build

Build script for Flutter proj.

Configured from the `fl_build:` section of the project's `pubspec.yaml`:

```yaml
fl_build:
  appName: ServerBox
```

`appName` is the only key without a default. It names the artifacts and the
generated `BuildData.name`. The rest — `beforeBuild`, `afterBuild`,
`buildDataClass`, `buildDataPath`, `customArgs`, `platformSetup` — are on
`MakeCfg`.

Windows builds target x64 by default. To build ARM64, pass Flutter's target
platform option after `--`:

```sh
dart run bin/fl_build.dart -p win -- --target-platform=windows-arm64
```

The ARM64 build is packaged from `build/windows/arm64/runner/Release` as a
`_windows_arm64.zip`. This requires a Flutter version and Windows build tools
that support the ARM64 target.
