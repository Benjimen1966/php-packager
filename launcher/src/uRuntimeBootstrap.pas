unit uRuntimeBootstrap;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uLogger;

procedure StartEmbeddedRuntime(const ExtractedRoot: string; Logger: TLogger);

implementation

uses
  Process, Windows, WinSock, ShellApi, fpjson, jsonparser, uExtractionValidation;

type
  TLauncherManifest = class
  public
    AppName: string;
    AppVersion: string;
    AppDir: string;
    PhpRuntime: string;
    DocumentRoot: string;
    EntryPoint: string;
    HealthcheckPath: string;
    OpenMode: string;
    PhpExtensionsRequired: TStringList;
    PhpIni: TStringList;
    constructor Create;
    destructor Destroy; override;
    class function LoadFromFile(const FileName: string): TLauncherManifest;
  end;

constructor TLauncherManifest.Create;
begin
  inherited Create;
  AppName := 'Mywbstd';
  AppVersion := '1.0.0';
  AppDir := '';
  PhpRuntime := 'php80';
  DocumentRoot := 'public';
  EntryPoint := 'index.php';
  HealthcheckPath := 'public/healthz.php';
  OpenMode := 'browser';
  PhpExtensionsRequired := TStringList.Create;
  PhpIni := TStringList.Create;
end;

destructor TLauncherManifest.Destroy;
begin
  PhpIni.Free;
  PhpExtensionsRequired.Free;
  inherited Destroy;
end;

function NormalizeRelPath(const S: string): string;
begin
  Result := StringReplace(Trim(S), '/', PathDelim, [rfReplaceAll]);
  while (Result <> '') and ((Result[1] = '\\') or (Result[1] = '/')) do
    Delete(Result, 1, 1);
end;

function NormalizeForwardPath(const S: string): string;
begin
  Result := StringReplace(Trim(S), '\\', '/', [rfReplaceAll]);
  while (Result <> '') and (Result[1] = '/') do
    Delete(Result, 1, 1);
end;

function GetJsonString(Obj: TJSONObject; const Key, DefaultValue: string): string;
begin
  if (Obj <> nil) and (Obj.Find(Key) <> nil) then
    Result := Obj.Get(Key, DefaultValue)
  else
    Result := DefaultValue;
end;

function IsSafeRelativePath(const S: string): Boolean;
var
  N: string;
begin
  N := StringReplace(Trim(S), '\\', '/', [rfReplaceAll]);
  if N = '' then
    Exit(True);

  if Pos(':', N) > 0 then
    Exit(False);
  if (Length(N) >= 2) and (Copy(N, 1, 2) = '//') then
    Exit(False);
  if N[1] = '/' then
    Exit(False);
  if Pos('/../', '/' + N + '/') > 0 then
    Exit(False);
  if (N = '..') or (Pos('../', N) = 1) or (Pos('/..', N) = Length(N) - 2) then
    Exit(False);

  Result := True;
end;

function NormalizeOpenMode(const S: string): string;
begin
  Result := LowerCase(Trim(S));
  if Result = '' then
    Result := 'browser';
end;

function ShouldOpenBrowser(const OpenMode: string): Boolean;
begin
  Result := not ((OpenMode = 'none') or (OpenMode = 'off') or (OpenMode = 'manual'));
end;

class function TLauncherManifest.LoadFromFile(const FileName: string): TLauncherManifest;
var
  Raw: TStringList;
  Root: TJSONData;
  Obj, IniObj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  IniData: TJSONData;
  V: string;
begin
  if not FileExists(FileName) then
    raise Exception.Create('Manifest not found: ' + FileName);

  Result := TLauncherManifest.Create;
  Raw := TStringList.Create;
  Root := nil;
  try
    Raw.LoadFromFile(FileName);
    Root := GetJSON(Raw.Text);
    if (Root = nil) or (Root.JSONType <> jtObject) then
      raise Exception.Create('Manifest JSON root is not an object: ' + FileName);

    Obj := TJSONObject(Root);
    Result.AppName := GetJsonString(Obj, 'app_name', Result.AppName);
    Result.AppVersion := GetJsonString(Obj, 'app_version', Result.AppVersion);
    Result.AppDir := NormalizeRelPath(GetJsonString(Obj, 'app_dir', Result.AppDir));
    Result.PhpRuntime := NormalizeRelPath(GetJsonString(Obj, 'php_runtime', Result.PhpRuntime));
    Result.DocumentRoot := NormalizeRelPath(GetJsonString(Obj, 'document_root', Result.DocumentRoot));
    Result.EntryPoint := NormalizeForwardPath(GetJsonString(Obj, 'entrypoint', Result.EntryPoint));
    Result.HealthcheckPath := NormalizeForwardPath(GetJsonString(Obj, 'healthcheck_path', Result.HealthcheckPath));
    Result.OpenMode := NormalizeOpenMode(GetJsonString(Obj, 'open_mode', Result.OpenMode));

    if not IsSafeRelativePath(Result.AppDir) then
      raise Exception.Create('Unsafe manifest app_dir path: ' + Result.AppDir);
    if not IsSafeRelativePath(Result.PhpRuntime) then
      raise Exception.Create('Unsafe manifest php_runtime path: ' + Result.PhpRuntime);
    if not IsSafeRelativePath(Result.DocumentRoot) then
      raise Exception.Create('Unsafe manifest document_root path: ' + Result.DocumentRoot);
    if not IsSafeRelativePath(Result.EntryPoint) then
      raise Exception.Create('Unsafe manifest entrypoint path: ' + Result.EntryPoint);

    if (Result.DocumentRoot <> '') and
      (Pos(LowerCase(Result.DocumentRoot) + '/', LowerCase(Result.EntryPoint)) = 1) then
      Delete(Result.EntryPoint, 1, Length(Result.DocumentRoot) + 1);

    Arr := Obj.Arrays['php_extensions_required'];
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        V := Trim(Arr.Strings[I]);
        if V <> '' then
          Result.PhpExtensionsRequired.Add(V);
      end;

    IniData := Obj.Find('php_ini');
    if (IniData <> nil) and (IniData.JSONType = jtObject) then
    begin
      IniObj := TJSONObject(IniData);
      for I := 0 to IniObj.Count - 1 do
      begin
        V := Trim(IniObj.Items[I].AsString);
        if V <> '' then
          Result.PhpIni.Values[IniObj.Names[I]] := V;
      end;
    end;
  except
    Result.Free;
    raise;
  end;

  Root.Free;
  Raw.Free;
end;

function AppendPath(const A, B: string): string;
begin
  Result := IncludeTrailingPathDelimiter(A) + B;
end;

function DirectoryContainsDocRoot(const Candidate, DocRoot: string): Boolean;
begin
  Result := DirectoryExists(AppendPath(Candidate, DocRoot));
end;

function ResolveAppRoot(const ExtractedRoot: string; Manifest: TLauncherManifest): string;
var
  AppBase, Candidate: string;
  SR: TSearchRec;
  SubdirCount: Integer;
  OnlySubdir: string;
begin
  if Manifest.AppDir <> '' then
  begin
    Result := AppendPath(ExtractedRoot, Manifest.AppDir);
    if not DirectoryExists(Result) then
      raise Exception.Create('Manifest app_dir does not exist: ' + Result);
    Exit;
  end;

  if DirectoryContainsDocRoot(ExtractedRoot, Manifest.DocumentRoot) then
    Exit(ExtractedRoot);

  AppBase := AppendPath(ExtractedRoot, 'app');
  if not DirectoryExists(AppBase) then
    raise Exception.Create('Unable to resolve app root. Missing app directory under: ' + ExtractedRoot);

  if DirectoryContainsDocRoot(AppBase, Manifest.DocumentRoot) then
    Exit(AppBase);

  SubdirCount := 0;
  OnlySubdir := '';
  if SysUtils.FindFirst(IncludeTrailingPathDelimiter(AppBase) + '*', faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        Inc(SubdirCount);
        OnlySubdir := SR.Name;
      end;
    until SysUtils.FindNext(SR) <> 0;
  finally
    SysUtils.FindClose(SR);
  end;

  if SubdirCount = 1 then
  begin
    Candidate := AppendPath(AppBase, OnlySubdir);
    if DirectoryContainsDocRoot(Candidate, Manifest.DocumentRoot) then
      Exit(Candidate);
  end;

  raise Exception.Create('Unable to resolve app root from extracted payload.');
end;

function ResolveRuntimeDir(const ExtractedRoot: string; Manifest: TLauncherManifest): string;
var
  Candidate: string;
begin
  if Pos(PathDelim, Manifest.PhpRuntime) > 0 then
    Candidate := AppendPath(ExtractedRoot, Manifest.PhpRuntime)
  else
    Candidate := AppendPath(AppendPath(ExtractedRoot, 'runtime'), Manifest.PhpRuntime);

  if not DirectoryExists(Candidate) then
    raise Exception.Create('PHP runtime directory not found: ' + Candidate);

  Result := Candidate;
end;

function BuildPhpIni(const RuntimeDir: string; Manifest: TLauncherManifest; Logger: TLogger): string;
var
  BasePath, OutputPath, ExtDir, ExtDllPath: string;
  L: TStringList;
  I: Integer;
  ExtName: string;
begin
  BasePath := AppendPath(RuntimeDir, 'php.ini.base');
  OutputPath := AppendPath(RuntimeDir, 'php.generated.ini');

  L := TStringList.Create;
  try
    if FileExists(BasePath) then
      L.LoadFromFile(BasePath)
    else
      Logger.Info('php.ini.base not found; using generated defaults only.');

    L.Add('');
    L.Add('; launcher-generated overrides');
    ExtDir := AppendPath(RuntimeDir, 'ext');
    L.Add('extension_dir="' + ExtDir + '"');

    for I := 0 to Manifest.PhpIni.Count - 1 do
      L.Add(Manifest.PhpIni.Names[I] + '=' + Manifest.PhpIni.ValueFromIndex[I]);

    for I := 0 to Manifest.PhpExtensionsRequired.Count - 1 do
    begin
      ExtName := Trim(Manifest.PhpExtensionsRequired[I]);
      if ExtName <> '' then
      begin
        ExtDllPath := AppendPath(ExtDir, 'php_' + ExtName + '.dll');
        if FileExists(ExtDllPath) then
          L.Add('extension=' + ExtName)
        else
          Logger.Info('Skipping missing PHP extension DLL: ' + ExtDllPath);
      end;
    end;

    L.SaveToFile(OutputPath);
  finally
    L.Free;
  end;

  Result := OutputPath;
end;

function IsPortAvailable(const Port: Word): Boolean;
var
  Wsa: WSAData;
  Sock: TSocket;
  Addr: TSockAddrIn;
begin
  Result := False;
  if WSAStartup($0202, Wsa) <> 0 then
    Exit;
  try
    Sock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if Sock = INVALID_SOCKET then
      Exit;
    try
      FillChar(Addr, SizeOf(Addr), 0);
      Addr.sin_family := AF_INET;
      Addr.sin_addr.S_addr := inet_addr('127.0.0.1');
      Addr.sin_port := htons(Port);
      Result := bind(Sock, Addr, SizeOf(Addr)) = 0;
    finally
      closesocket(Sock);
    end;
  finally
    WSACleanup;
  end;
end;

function WaitPortListening(const Port: Word; const TimeoutMs: Cardinal): Boolean;
var
  Wsa: WSAData;
  Sock: TSocket;
  Addr: TSockAddrIn;
  StartAt: QWord;
begin
  Result := False;
  if WSAStartup($0202, Wsa) <> 0 then
    Exit;
  try
    StartAt := GetTickCount64;
    while (GetTickCount64 - StartAt) < TimeoutMs do
    begin
      Sock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
      if Sock = INVALID_SOCKET then
        Break;
      try
        FillChar(Addr, SizeOf(Addr), 0);
        Addr.sin_family := AF_INET;
        Addr.sin_addr.S_addr := inet_addr('127.0.0.1');
        Addr.sin_port := htons(Port);
        if connect(Sock, Addr, SizeOf(Addr)) = 0 then
        begin
          Result := True;
          Exit;
        end;
      finally
        closesocket(Sock);
      end;
      Sleep(120);
    end;
  finally
    WSACleanup;
  end;
end;

function FindAvailablePort: Word;
var
  P: Word;
begin
  for P := 18080 to 18120 do
    if IsPortAvailable(P) then
      Exit(P);
  raise Exception.Create('No available localhost port found in range 18080-18120');
end;

procedure OpenUrlInBrowser(const Url: string);
var
  R: HINST;
begin
  R := ShellExecute(0, 'open', PChar(Url), nil, nil, SW_SHOWNORMAL);
  if R <= 32 then
    raise Exception.Create('Failed to open browser URL: ' + Url);
end;

procedure StartEmbeddedRuntime(const ExtractedRoot: string; Logger: TLogger);
var
  ManifestPath: string;
  Manifest: TLauncherManifest;
  AppRoot, RuntimeDir, PhpExe, PhpIniPath, DocRoot, EntryPointFsPath: string;
  Port: Word;
  Proc: TProcess;
  Url: string;
begin
  ManifestPath := AppendPath(ExtractedRoot, 'manifest.json');
  Manifest := TLauncherManifest.LoadFromFile(ManifestPath);
  try
    AppRoot := ResolveAppRoot(ExtractedRoot, Manifest);
    RuntimeDir := ResolveRuntimeDir(ExtractedRoot, Manifest);
    PhpExe := AppendPath(RuntimeDir, 'php.exe');
    RequireFileExists(PhpExe, 'PHP executable');

    DocRoot := AppendPath(AppRoot, Manifest.DocumentRoot);
    RequireDirectoryExists(DocRoot, 'Document root');

    EntryPointFsPath := AppendPath(DocRoot, StringReplace(Manifest.EntryPoint, '/', PathDelim, [rfReplaceAll]));
    RequireFileExists(EntryPointFsPath, 'Entrypoint script');

    PhpIniPath := BuildPhpIni(RuntimeDir, Manifest, Logger);
    Port := FindAvailablePort;

    Proc := TProcess.Create(nil);
    try
      Proc.Executable := PhpExe;
      Proc.CurrentDirectory := AppRoot;
      Proc.Options := [poNoConsole, poNewProcessGroup];
      Proc.Parameters.Add('-c');
      Proc.Parameters.Add(PhpIniPath);
      Proc.Parameters.Add('-S');
      Proc.Parameters.Add('127.0.0.1:' + IntToStr(Port));
      Proc.Parameters.Add('-t');
      Proc.Parameters.Add(DocRoot);

      Logger.Info('Starting PHP runtime: ' + Proc.Executable + ' -S 127.0.0.1:' + IntToStr(Port));
      Proc.Execute;

      if not WaitPortListening(Port, 7000) then
        raise Exception.Create('PHP server did not become ready on port ' + IntToStr(Port));

      Url := 'http://127.0.0.1:' + IntToStr(Port) + '/' + Manifest.EntryPoint;
      if ShouldOpenBrowser(Manifest.OpenMode) then
      begin
        Logger.Info('Opening app URL: ' + Url);
        OpenUrlInBrowser(Url);
      end
      else
      begin
        Logger.Info('Open mode is ' + Manifest.OpenMode + '; app URL: ' + Url);
        Writeln('App started at: ' + Url);
      end;
    finally
      Proc.Free;
    end;
  finally
    Manifest.Free;
  end;
end;

end.
