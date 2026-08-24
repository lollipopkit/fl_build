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
