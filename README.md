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

### Windows installer

With a `windows/installer.iss` in the project, `-p windows` also compiles it
with Inno Setup 6 (`ISCC` env, its default install path, or `PATH`) into
`<appName>_<build>_windows_amd64.exe`, next to the zip. The script gets
`AppName`, `AppVersion`, `SourceDir`, `OutputDir` and `OutputBaseFilename` as
`/D` defines.
