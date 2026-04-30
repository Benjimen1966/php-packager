
program updater;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Process, Windows, ShellApi, fpjson, jsonparser,
  uVersionSwitch, uPathUtils, uSHA256;

var
  AppExe, AppVersion, AppName, RootDir, UpdateManifest, UpdateSignature, SignerThumbprint: string;
  WaitPid: Cardinal;

function ParseWaitPid(const S: string): Cardinal;
var
  V: QWord;
begin
  Result := 0;
  if not TryStrToQWord(Trim(S), V) then
    Exit;
  if V > High(Cardinal) then
    Exit;
  Result := Cardinal(V);
end;

procedure WaitForProcessExit(const Pid: Cardinal; const TimeoutMs: Cardinal);
var
  H: THandle;
begin
  if Pid = 0 then
    Exit;

  H := OpenProcess(SYNCHRONIZE, False, Pid);
  if H = 0 then
    Exit;
  try
    WaitForSingleObject(H, TimeoutMs);
  finally
    CloseHandle(H);
  end;
end;

procedure RelaunchApp(const ExePath: string);
var
  R: HINST;
begin
  R := ShellExecute(0, 'open', PChar(ExePath), nil, PChar(ExtractFileDir(ExePath)), SW_SHOWNORMAL);
  if R <= 32 then
    raise Exception.Create('Failed to relaunch app: ' + ExePath);
end;

function RunAndCapture(const ExePath: string; const Args: array of string; out StdOut: string): Integer;
var
  P: TProcess;
  S: TStringStream;
  I: Integer;
begin
  StdOut := '';
  P := TProcess.Create(nil);
  S := TStringStream.Create('');
  try
    P.Executable := ExePath;
    for I := Low(Args) to High(Args) do
      P.Parameters.Add(Args[I]);
    P.Options := [poUsePipes, poWaitOnExit];
    P.ShowWindow := swoHIDE;
    P.Execute;
    S.CopyFrom(P.Output, 0);
    StdOut := Trim(S.DataString);
    Result := P.ExitStatus;
  finally
    S.Free;
    P.Free;
  end;
end;

procedure VerifySignedManifest(const AppExePath, ExpectedVersion, ManifestPath, SignaturePath, ExpectedThumbprint: string);
var
  Raw: TStringList;
  Root: TJSONData;
  Obj: TJSONObject;
  ManifestVersion, ManifestHash, ActualHash: string;
  VerifyScript, PowerShellExe, VerifyOutput, Thumb: string;
  ExitCode: Integer;
begin
  if not FileExists(ManifestPath) then
    raise Exception.Create('Update manifest not found: ' + ManifestPath);
  if not FileExists(SignaturePath) then
    raise Exception.Create('Update manifest signature not found: ' + SignaturePath);

  Raw := TStringList.Create;
  Root := nil;
  try
    Raw.LoadFromFile(ManifestPath);
    Root := GetJSON(Raw.Text);
    if (Root = nil) or (Root.JSONType <> jtObject) then
      raise Exception.Create('Update manifest root must be a JSON object: ' + ManifestPath);

    Obj := TJSONObject(Root);
    ManifestVersion := Trim(Obj.Get('app_version', ''));
    ManifestHash := LowerCase(Trim(Obj.Get('app_exe_sha256', '')));

    if ManifestVersion = '' then
      raise Exception.Create('Update manifest missing app_version: ' + ManifestPath);
    if ManifestHash = '' then
      raise Exception.Create('Update manifest missing app_exe_sha256: ' + ManifestPath);

    if ManifestVersion <> ExpectedVersion then
      raise Exception.Create('Update manifest version mismatch. Expected=' + ExpectedVersion + ' Manifest=' + ManifestVersion);

    ActualHash := LowerCase(SHA256OfFileHex(AppExePath));
    if ActualHash <> ManifestHash then
      raise Exception.Create('App EXE hash mismatch. Expected=' + ManifestHash + ' Actual=' + ActualHash);
  finally
    Root.Free;
    Raw.Free;
  end;

  VerifyScript := ExpandFileName(ExtractFileDir(ParamStr(0)) + '\\..\\tools\\verify_update_manifest.ps1');
  if not FileExists(VerifyScript) then
    raise Exception.Create('Manifest verification script not found: ' + VerifyScript);

  PowerShellExe := 'powershell.exe';

  ExitCode := RunAndCapture(PowerShellExe,
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', VerifyScript,
     '-ManifestJson', ManifestPath, '-SignatureFile', SignaturePath],
    VerifyOutput);
  if ExitCode <> 0 then
    raise Exception.Create('Update manifest signature verification failed: ' + VerifyOutput);

  Thumb := LowerCase(StringReplace(VerifyOutput, ' ', '', [rfReplaceAll]));
  if (ExpectedThumbprint <> '') and (Thumb <> LowerCase(StringReplace(ExpectedThumbprint, ' ', '', [rfReplaceAll]))) then
    raise Exception.Create('Signer thumbprint mismatch. Expected=' + ExpectedThumbprint + ' Actual=' + VerifyOutput);
end;

begin
  if ParamCount < 2 then
  begin
    Writeln('Usage: updater <app_exe> <app_version> [wait_pid] [manifest.json] [manifest.sig] [signer_thumbprint]');
    Halt(1);
  end;

  AppExe := ExpandFileName(ParamStr(1));
  AppVersion := Trim(ParamStr(2));
  if ParamCount >= 3 then
    WaitPid := ParseWaitPid(ParamStr(3))
  else
    WaitPid := 0;

  if ParamCount >= 4 then
    UpdateManifest := ExpandFileName(ParamStr(4))
  else
    UpdateManifest := '';

  if ParamCount >= 5 then
    UpdateSignature := ExpandFileName(ParamStr(5))
  else
    UpdateSignature := '';

  if ParamCount >= 6 then
    SignerThumbprint := Trim(ParamStr(6))
  else
    SignerThumbprint := '';

  try
    if not FileExists(AppExe) then
      raise Exception.Create('Target app EXE not found: ' + AppExe);
    if AppVersion = '' then
      raise Exception.Create('App version is required.');

    AppName := ChangeFileExt(ExtractFileName(AppExe), '');
    if AppName = '' then
      AppName := 'Mywbstd';

    if WaitPid <> 0 then
      WaitForProcessExit(WaitPid, 120000);

    if (UpdateManifest <> '') or (UpdateSignature <> '') then
    begin
      if (UpdateManifest = '') or (UpdateSignature = '') then
        raise Exception.Create('Both manifest.json and manifest.sig are required for signature verification mode.');
      VerifySignedManifest(AppExe, AppVersion, UpdateManifest, UpdateSignature, SignerThumbprint);
    end;

    RootDir := GetAppDataRoot(AppName);
    WriteCurrentVersionPointer(RootDir, AppVersion);

    RelaunchApp(AppExe);
    Writeln('Updater complete. current.txt=' + AppVersion);
  except
    on E: Exception do
    begin
      Writeln('ERROR: ' + E.Message);
      Halt(2);
    end;
  end;
end.
