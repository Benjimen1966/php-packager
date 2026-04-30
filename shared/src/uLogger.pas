
unit uLogger;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLogger = class
  private
    FLogFile: string;
    procedure EnsureParentDir;
    procedure AppendLine(const Line: string);
  public
    constructor Create(const ALogFile: string);
    procedure Info(const Msg: string);
    procedure Error(const Msg: string);
    property LogFile: string read FLogFile;
  end;

implementation

constructor TLogger.Create(const ALogFile: string);
begin
  inherited Create;
  FLogFile := ALogFile;
  EnsureParentDir;
end;

procedure TLogger.EnsureParentDir;
begin
  ForceDirectories(ExtractFileDir(FLogFile));
end;

procedure TLogger.AppendLine(const Line: string);
var
  FS: TFileStream;
  S: UTF8String;
begin
  EnsureParentDir;
  S := UTF8String(Line + LineEnding);
  if FileExists(FLogFile) then
    FS := TFileStream.Create(FLogFile, fmOpenReadWrite or fmShareDenyNone)
  else
    FS := TFileStream.Create(FLogFile, fmCreate);
  try
    FS.Seek(0, soEnd);
    if Length(S) > 0 then
      FS.WriteBuffer(Pointer(S)^, Length(S));
  finally
    FS.Free;
  end;
end;

procedure TLogger.Info(const Msg: string);
begin
  AppendLine(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [INFO] ' + Msg);
end;

procedure TLogger.Error(const Msg: string);
begin
  AppendLine(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [ERROR] ' + Msg);
end;

end.
