# Packager User Guide

This guide explains how to package your PHP app into a single Windows EXE using this workspace.

## What You Get

After a successful release build, the primary output is:

- `dist/Mywbstd.exe`

Optional additional outputs:

- `dist/launcher_stub.exe`
- `dist/embed_cli.exe`
- `dist/updater.exe`

## Prerequisites

Install and verify:

1. Lazarus + Free Pascal Compiler (FPC 3.2.2 or compatible)
2. PowerShell (for manifest generation script)
3. Windows environment (current scripts and runtime are Windows-focused)

FPC lookup order used by scripts:

1. `%FPC%` environment variable
2. `C:\lazarus40\fpc\3.2.2\bin\x86_64-win64\fpc.exe`
3. `fpc` from `PATH`

If your `fpc.exe` is elsewhere, set:

```bat
set FPC=C:\path\to\fpc.exe
```

## Required Staging Layout

Prepare your payload under `staging/`:

```text
staging/
  app/
    your-app/
      public/
        index.php
  runtime/
    php80/
      php.exe
      php.ini.base
      ext/
  packager.yml
```

Key requirement:

- The PHP runtime must include `php.exe` and extension DLLs under `ext/`.

## Configure packager.yml

Edit `staging/packager.yml`.

Common keys:

- `app_name`
- `app_version`
- `app_dir`
- `document_root`
- `entrypoint`
- `healthcheck_path`
- `php_runtime`
- `open_mode`
- `output_dir`
- `work_dir`
- `php_extensions_required`
- `php_ini`
- `exclude`

Example:

```yaml
app_name: Mywbstd
app_version: 1.0.0
app_dir: app/wb-std
document_root: public
entrypoint: public/index.php
healthcheck_path: public/healthz.php
php_runtime: runtime/php80
open_mode: browser
output_dir: dist
work_dir: work
php_extensions_required:
  - bcmath
  - curl
  - mbstring
  - mysqli
  - openssl
  - pdo_mysql
php_ini:
  memory_limit: 256M
  max_execution_time: 60
  post_max_size: 32M
  upload_max_filesize: 32M
exclude:
  - .git
  - node_modules
  - tests
  - docs
```

Notes:

- `entrypoint` can be `public/index.php` or `index.php`; manifest generation normalizes it.
- `app_dir` is emitted into `manifest.json` and used by launcher app-root resolution when present.
- `exclude` is emitted into `manifest.json` and applied during ZIP payload creation.
- `open_mode: manual` (or `none`/`off`) keeps runtime running but does not auto-open browser.
- `output_dir` controls the default final embedded EXE destination in `build_release.bat`.
- `work_dir` controls where temporary payload ZIP files are created during embedding.
- Missing `php_extensions_required` and `php_ini` will use built-in defaults.

## Build Commands

Run these from the workspace root.

### One-command release build (recommended)

```bat
tools\build_release.bat
```

This does:

1. Generate `staging/manifest.json` from `staging/packager.yml`
2. Build launcher, builder, updater
3. Create embedded EXE `dist/Mywbstd.exe`

Optional signing during release build:

- Set `SIGN_CERT_SHA1` to your code-signing certificate thumbprint.
- Optional: set `SIGNTOOL` to explicit `signtool.exe` path.
- Optional: set `SIGN_TIMESTAMP_URL` to custom RFC3161 timestamp URL.

When `SIGN_CERT_SHA1` is set, `tools/build_release.bat` signs:

- `launcher_stub.exe`
- `updater.exe`
- final packaged app EXE

#### Strict release mode (enforce signing)

Set `STRICT_RELEASE=1` to make signing **mandatory**. If `SIGN_CERT_SHA1` is not configured when `STRICT_RELEASE=1`, the build will **fail immediately** with an error instead of producing an unsigned artifact.

```bat
set STRICT_RELEASE=1
set SIGN_CERT_SHA1=<thumbprint>
tools\build_release.bat
```

This applies to both `tools/build_release.bat` and `tools/build_installer.bat`. Use this on CI/CD pipelines or release branches to prevent accidentally shipping unsigned binaries.

### Build binaries only

```bat
tools\build_all.bat
```

This builds launcher, builder, updater but does not embed the final app EXE.

### Manual embed step

If binaries already exist:

```bat
tools\embed_release.bat dist\launcher_stub.exe staging dist\Mywbstd.exe 1.0.0
```

## Run and Validate

Start your packaged app:

```bat
dist\Mywbstd.exe
```

At first run, launcher will:

1. Verify embedded payload hash
2. Extract to `%LOCALAPPDATA%\Mywbstd\versions\<version_hash>`
3. Generate runtime ini (`php.generated.ini`)
4. Start PHP built-in server on localhost port `18080..18120`
5. Open browser to your configured entrypoint

Useful runtime paths:

- Logs: `%LOCALAPPDATA%\Mywbstd\logs\startup.log`
- Extracted app/runtime: `%LOCALAPPDATA%\Mywbstd\versions\...`

## Installer Build (Optional)

After creating app artifacts in configured `output_dir`, run:

```bat
tools\build_installer.bat
```

This creates an installer that deploys app + updater and shortcuts. The script automatically passes `output_dir` from `staging/manifest.json` into `installer/setup.iss`.

## Updater Usage (Current)

The updater now supports pointer switch + relaunch mode:

```bat
dist\updater.exe dist\Mywbstd.exe 1.0.1
```

Optional third argument waits for an existing process ID before relaunch:

```bat
dist\updater.exe dist\Mywbstd.exe 1.0.1 12345
```

Current behavior:

1. Optionally waits for PID exit
2. Writes `%LOCALAPPDATA%\<AppName>\current.txt`
3. Relaunches target app EXE

Signed update-manifest verification mode:

```bat
updater.exe <app_exe> <app_version> [wait_pid] <manifest.json> <manifest.sig> [signer_thumbprint]
```

Helper scripts:

- Generate manifest with app hash: `tools/generate_update_manifest.ps1`
- Sign manifest (CMS detached signature): `tools/sign_update_manifest.ps1`
- Verify signature: `tools/verify_update_manifest.ps1`

Required manifest fields for updater verification:

- `app_version`
- `app_exe_sha256`

## Troubleshooting

### Error: Free Pascal compiler not found

Fix:

- Set `%FPC%` to your compiler path, or add `fpc` to `PATH`.

### Error: Embedded footer not found or invalid

Cause:

- You are running `launcher_stub.exe` directly, not the packaged EXE.

Fix:

- Run `dist/Mywbstd.exe` created by `build_release.bat`.

### Error: php.exe not found

Fix:

- Ensure `staging/runtime/php80/php.exe` exists before packaging.

### Browser does not open or app fails to start

Check:

- `startup.log` for exact exception
- port conflicts on `18080..18120`
- existence of `document_root` and `entrypoint` in extracted app

### Missing extension warnings

Cause:

- Extension listed in `php_extensions_required` but DLL missing in `runtime/php80/ext`.

Fix:

- Add matching `php_<ext>.dll` or remove extension from config.

## Current Limitations

`output_dir` and `work_dir` are now operational in release flow.

Current limits for these fields:

- They are used as defaults by `tools/build_release.bat`; explicit CLI arguments still override output EXE path/version.
- Intermediate artifacts (`launcher_stub.exe`, `embed_cli.exe`, `updater.exe`) are emitted to `output_dir` by the component build scripts.

Also note:

- Signed update metadata, rollback strategy, and anti-downgrade controls are not complete yet.

## Smoke Test

Run a quick automated artifact smoke test:

```powershell
.\tools\smoke_test_release.ps1 -SkipLaunch
```

This verifies packaged EXEs exist in configured `output_dir`.
