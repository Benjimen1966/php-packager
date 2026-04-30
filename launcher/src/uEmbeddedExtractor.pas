
unit uEmbeddedExtractor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uEmbedFooter, uLogger;

type
  TEmbeddedExtractor = class
  private
    class function ReadPayloadToMemory(const ExePath: string; const Footer: TEmbedFooter): TMemoryStream;
    class function ExtractZipToDir(const ZipFile, DestDir: string): Boolean;
    class function MarkerPath(const DestDir: string): string;
  public
    class function EnsureExtracted(const SelfExe, AppName: string; Logger: TLogger): string;
  end;

implementation

uses
  zipper, uSHA256, uPathUtils;

class function TEmbeddedExtractor.ReadPayloadToMemory(const ExePath: string; const Footer: TEmbedFooter): TMemoryStream;
var
  FS: TFileStream;
begin
  Result := TMemoryStream.Create;
  FS := TFileStream.Create(ExePath, fmOpenRead or fmShareDenyWrite);
  try
    FS.Position := Footer.PayloadOffset;
    Result.CopyFrom(FS, Footer.PayloadSize);
    Result.Position := 0;
  finally
    FS.Free;
  end;
end;

class function TEmbeddedExtractor.ExtractZipToDir(const ZipFile, DestDir: string): Boolean;
var
  U: TUnZipper;
begin
  Result := False;
  ForceDirectories(DestDir);
  U := TUnZipper.Create;
  try
    U.FileName := ZipFile;
    U.OutputPath := IncludeTrailingPathDelimiter(DestDir);
    U.Examine;
    U.UnZipAllFiles;
    Result := True;
  finally
    U.Free;
  end;
end;

class function TEmbeddedExtractor.MarkerPath(const DestDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(DestDir) + '.extract.ok';
end;

class function TEmbeddedExtractor.EnsureExtracted(const SelfExe, AppName: string; Logger: TLogger): string;
var
  Footer: TEmbedFooter;
  Version, RootDir, VersionsDir, DestDir, Marker, TempZip, CacheKey: string;
  PayloadMs: TMemoryStream;
  FS: TFileStream;
  MarkerText: TStringList;
  ActualHash, ExpectedHash: string;
  ExistingHash, ManifestPath: string;
begin
  if not ReadFooterFromExe(SelfExe, Footer) then
    raise Exception.Create('Embedded footer not found or invalid in: ' + SelfExe);

  Version := FooterAppVersion(Footer);
  if Version = '' then
    raise Exception.Create('Embedded app version missing in footer');

  Logger.Info('Embedded footer read successfully. Version=' + Version);

  PayloadMs := ReadPayloadToMemory(SelfExe, Footer);
  try
    ActualHash := SHA256OfStreamHex(PayloadMs);
    ExpectedHash := LowerCase(FooterPayloadHash(Footer));
    if ActualHash <> ExpectedHash then
      raise Exception.Create('Embedded payload SHA-256 mismatch. Expected=' + ExpectedHash + ' Actual=' + ActualHash);
    Logger.Info('Payload SHA-256 verified.');

    RootDir := GetAppDataRoot(AppName);
    VersionsDir := EnsureDir(CombinePath(RootDir, 'versions'));
    CacheKey := Version + '_' + Copy(LowerCase(ActualHash), 1, 12);
    DestDir := EnsureDir(CombinePath(VersionsDir, CacheKey));
    Marker := MarkerPath(DestDir);
    ManifestPath := IncludeTrailingPathDelimiter(DestDir) + 'manifest.json';

    if FileExists(Marker) then
    begin
      ExistingHash := '';
      MarkerText := TStringList.Create;
      try
        MarkerText.LoadFromFile(Marker);
        if MarkerText.Count > 0 then
          ExistingHash := Trim(LowerCase(MarkerText[0]));
      finally
        MarkerText.Free;
      end;

      if (ExistingHash = LowerCase(ActualHash)) and FileExists(ManifestPath) then
      begin
        Logger.Info('Existing extracted version reused: ' + DestDir);
        Exit(DestDir);
      end;

      Logger.Info('Existing extracted cache invalidated; refreshing: ' + DestDir);
      DeleteFile(Marker);
    end;

    TempZip := IncludeTrailingPathDelimiter(RootDir) + 'temp\\payload_' + CacheKey + '.zip';
    ForceDirectories(ExtractFileDir(TempZip));

    FS := TFileStream.Create(TempZip, fmCreate);
    try
      PayloadMs.Position := 0;
      FS.CopyFrom(PayloadMs, 0);
    finally
      FS.Free;
    end;

    Logger.Info('Extracting payload to: ' + DestDir);
    if not ExtractZipToDir(TempZip, DestDir) then
      raise Exception.Create('ZIP extraction failed.');

    FS := TFileStream.Create(Marker, fmCreate);
    try
      if Length(ActualHash) > 0 then
        FS.WriteBuffer(Pointer(ActualHash)^, Length(ActualHash));
    finally
      FS.Free;
    end;

    Logger.Info('Extraction complete. Marker written: ' + Marker);
    Result := DestDir;
  finally
    PayloadMs.Free;
  end;
end;

end.
