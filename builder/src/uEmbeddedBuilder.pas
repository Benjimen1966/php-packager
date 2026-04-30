
unit uEmbeddedBuilder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uEmbedFooter;

type
  TEmbeddedBuilder = class
  public
    class procedure BuildEmbeddedExe(const LauncherStubExe, StagingDir, OutputExe, AppVersion: string; const WorkDir: string = '');
  end;

implementation

uses
  uZipBuilder, uSHA256;

class procedure CopyFileStrict(const Src, Dst: string);
var
  InS, OutS: TFileStream;
begin
  ForceDirectories(ExtractFileDir(Dst));
  InS := TFileStream.Create(Src, fmOpenRead or fmShareDenyWrite);
  try
    OutS := TFileStream.Create(Dst, fmCreate);
    try
      OutS.CopyFrom(InS, 0);
    finally
      OutS.Free;
    end;
  finally
    InS.Free;
  end;
end;

class procedure AppendFileToStream(const FileName: string; Dest: TStream);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Dest.CopyFrom(FS, 0);
  finally
    FS.Free;
  end;
end;

class procedure TEmbeddedBuilder.BuildEmbeddedExe(const LauncherStubExe, StagingDir, OutputExe, AppVersion: string; const WorkDir: string = '');
var
  TempZip, WorkDirEffective, ZipName: string;
  OutS: TFileStream;
  Footer: TEmbedFooter;
  PayloadOffset, PayloadSize: Int64;
  PayloadSha256: string;
begin
  if not FileExists(LauncherStubExe) then
    raise Exception.Create('Launcher stub EXE not found: ' + LauncherStubExe);
  if not DirectoryExists(StagingDir) then
    raise Exception.Create('Staging directory not found: ' + StagingDir);

  if Trim(WorkDir) <> '' then
    WorkDirEffective := ExpandFileName(WorkDir)
  else
    WorkDirEffective := ExpandFileName(ExtractFileDir(OutputExe));

  ForceDirectories(WorkDirEffective);
  ZipName := ChangeFileExt(ExtractFileName(OutputExe), '.payload.zip');
  TempZip := IncludeTrailingPathDelimiter(WorkDirEffective) + ZipName;
  TZipBuilder.ZipDirectory(StagingDir, TempZip);
  PayloadSha256 := SHA256OfFileHex(TempZip);

  CopyFileStrict(LauncherStubExe, OutputExe);

  OutS := TFileStream.Create(OutputExe, fmOpenReadWrite);
  try
    OutS.Seek(0, soEnd);
    PayloadOffset := OutS.Position;
    AppendFileToStream(TempZip, OutS);
    PayloadSize := OutS.Position - PayloadOffset;
    InitFooter(Footer, PayloadOffset, PayloadSize, PayloadSha256, AppVersion);
    WriteFooterToStream(OutS, Footer);
  finally
    OutS.Free;
  end;

  if FileExists(TempZip) then
    DeleteFile(TempZip);
end;

end.
