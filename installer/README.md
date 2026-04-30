# Installer

Build this installer with Inno Setup after you have produced:

- packaged app EXE in configured `output_dir`
- `updater.exe` in configured `output_dir`

Recommended command from workspace root:

```bat
tools\build_installer.bat
```

This script reads `staging/manifest.json` and passes `output_dir` into `installer/setup.iss`.

The script installs to the current user's LocalAppData Programs folder.
