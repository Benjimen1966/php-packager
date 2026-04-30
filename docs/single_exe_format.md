# Single EXE Format

The final file is logically:

```text
[launcher stub EXE][payload ZIP][footer]
```

## Footer fields

- Magic = `PHPPACK1`
- FooterVersion
- PayloadOffset
- PayloadSize
- ManifestOffset
- ManifestSize
- PayloadSha256Hex
- AppVersion
- Reserved

The launcher reads the footer from the end of its own executable.

## Cache layout

```text
%LOCALAPPDATA%\Mywbstd\
  versions\
    1.0.0\
      app\
      runtime\
      manifest.json
      .extract.ok
  logs\
  temp\
```

## Marker file

`.extract.ok` is written only after extraction and validation succeed.
