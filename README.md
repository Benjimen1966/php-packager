# PHP Packager 1.0.0

Pack any PHP web application into a single self-contained Windows EXE — no installer required on the end-user machine.

## How it works

1. You supply your PHP app source and a Windows PHP runtime (e.g. PHP 8.0 NTS).
2. The packager bundles them into a single EXE using a launcher stub.
3. The end user runs the EXE. It extracts to `%LOCALAPPDATA%`, starts PHP's built-in server, and opens a browser — no PHP installation needed on the target machine.

## Contents of this archive

```
php-packager-1.0.0\
  bin\
    embed_cli.exe       ← packaging tool (creates the final EXE)
    launcher_stub.exe   ← launcher template embedded into every packaged app
    updater.exe         ← optional: in-place app updater helper
  builder\src\          ← Pascal source (reference / recompile if needed)
  launcher\src\
  updater\src\
  shared\src\
  installer\
    setup.iss           ← Inno Setup template for creating an installer
  tools\
    build_release.bat   ← one-command release build
    build_installer.bat ← optional Inno Setup installer build
    generate_manifest.ps1
    smoke_test_release.ps1
    (and more)
  examples\
    packager.yml        ← annotated configuration example
    manifest.json
  docs\
    packager_user_guide.md
  README.md             ← this file
```

## Prerequisites

| Requirement | Notes |
|---|---|
| Windows 10 / 11 (x64) | Build and target platform |
| [Lazarus IDE + FPC 3.2.2](https://www.lazarus-ide.org/) | Required to compile launcher / builder / updater from source. Not needed if using pre-built `bin\` binaries. |
| PowerShell 5.1+ | For manifest generation and release scripts |
| [Inno Setup 6](https://jrsoftware.org/isinfo.php) | Optional — only needed for `build_installer.bat` |
| Windows SDK `signtool.exe` | Optional — only needed for Authenticode signing |

## Quick start

### 1. Prepare your staging folder

Create a `staging\` folder at the root of this archive:

```
staging\
  packager.yml         ← your configuration (copy from examples\packager.yml)
  app\
    your-app\
      public\
        index.php      ← your PHP entry point
        healthz.php    ← optional health check (return HTTP 200)
  runtime\
    php80\
      php.exe
      php.ini.base     ← minimal php.ini (can be empty)
      ext\
        *.dll          ← PHP extension DLLs
```

Download a **Windows PHP NTS x64** build from [windows.php.net/download](https://windows.php.net/download/) and extract it into `staging\runtime\php80\`.

### 2. Configure packager.yml

Copy `examples\packager.yml` to `staging\packager.yml` and edit it:

```yaml
app_name: MyApp
app_version: 1.0.0
app_dir: app/your-app
document_root: public
entrypoint: public/index.php
healthcheck_path: public/healthz.php
php_runtime: runtime/php80
open_mode: browser        # browser | manual | none
output_dir: dist
work_dir: work
php_extensions_required:
  - mbstring
  - openssl
php_ini:
  memory_limit: 256M
  max_execution_time: 60
  post_max_size: 32M
  upload_max_filesize: 32M
exclude:
  - .git
  - node_modules
  - tests
```

**Key fields:**

| Field | Description |
|---|---|
| `app_name` | Name of the output EXE (no spaces) |
| `app_version` | Semantic version string |
| `app_dir` | Path inside `staging\` to your app root |
| `document_root` | Subfolder served by PHP built-in server |
| `entrypoint` | PHP file to open in the browser |
| `healthcheck_path` | File polled to confirm PHP server is ready |
| `php_runtime` | Path inside `staging\` to your PHP runtime |
| `open_mode` | `browser` auto-opens browser; `manual`/`none` does not |
| `output_dir` | Where the output EXE and binaries are placed |
| `work_dir` | Temp folder used during packaging |
| `exclude` | Glob patterns excluded from the embedded payload |

### 3. Build

Copy the pre-built binaries from `bin\` to `dist\` (skip recompiling Pascal source):

```bat
mkdir dist
copy bin\launcher_stub.exe dist\
copy bin\embed_cli.exe dist\
copy bin\updater.exe dist\
```

Then run the embed step:

```bat
tools\embed_release.bat dist\launcher_stub.exe staging dist\MyApp.exe 1.0.0
```

Or run the full one-command build (requires Lazarus/FPC — recompiles everything):

```bat
tools\build_release.bat
```

Output: `dist\MyApp.exe`

### 4. Test

```bat
dist\MyApp.exe
```

The app extracts to `%LOCALAPPDATA%\MyApp\versions\<version_hash>\` and opens your browser at `http://localhost:18080` (or the next available port up to 18120).

Logs: `%LOCALAPPDATA%\MyApp\logs\startup.log`

### 5. Build an installer (optional)

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php):

```bat
tools\build_installer.bat
```

Output: a setup EXE in `dist\`.

## Signing (optional)

Set `SIGN_CERT_SHA1` to your Authenticode certificate thumbprint before building to sign all output EXEs:

```bat
set SIGN_CERT_SHA1=<your certificate thumbprint>
tools\build_release.bat
```

Set `STRICT_RELEASE=1` to enforce signing — the build will fail immediately if `SIGN_CERT_SHA1` is not set:

```bat
set STRICT_RELEASE=1
set SIGN_CERT_SHA1=<thumbprint>
tools\build_release.bat
```

## Environment variables reference

| Variable | Purpose |
|---|---|
| `SIGN_CERT_SHA1` | Authenticode certificate thumbprint — enables EXE signing |
| `STRICT_RELEASE` | Set to `1` to fail build if `SIGN_CERT_SHA1` is not configured |
| `SIGN_TIMESTAMP_URL` | Custom RFC3161 timestamp server (default: DigiCert) |
| `SIGNTOOL` | Explicit path to `signtool.exe` |
| `FPC` | Explicit path to `fpc.exe` if not on PATH |
| `ISCC` | Explicit path to Inno Setup compiler `ISCC.exe` |

## Runtime behaviour (end user)

When the end user runs the packaged EXE:

1. Verifies embedded payload SHA-256 checksum.
2. Extracts to `%LOCALAPPDATA%\<AppName>\versions\<version_hash>\` — only on first run or after an update.
3. Starts PHP built-in server on `localhost:18080` (tries ports up to 18120).
4. Waits for the health check endpoint to respond.
5. Opens the default browser to the configured entrypoint.

## Updater (optional)

`bin\updater.exe` supports in-place version switching:

```
updater.exe <app_exe> <new_version> [wait_pid] [manifest.json] [manifest.sig] [signer_thumbprint]
```

- Waits for `wait_pid` to exit, then replaces the app EXE and relaunches.
- Optionally verifies a signed update manifest (SHA-256 + CMS/PKCS#7 signature) before proceeding.

See `docs\updater_notes.md` for full details.

## Recompiling from source

If you need to modify the launcher, builder, or updater:

1. Install [Lazarus IDE](https://www.lazarus-ide.org/) with FPC 3.2.2.
2. Open the relevant `.lpi` project file:
   - `launcher\launcher.lpi`
   - `builder\embed_cli.lpi`
   - `updater\updater.lpi`
3. Build from Lazarus, or run `tools\build_release.bat` — it compiles everything automatically.

## Further reading

- `docs\packager_user_guide.md` — full configuration and build reference
- `docs\single_exe_format.md` — binary format specification
- `docs\updater_notes.md` — updater integration guide
- `docs\installer_notes.md` — Inno Setup customisation guide
- `examples\packager.yml` — fully annotated configuration example
