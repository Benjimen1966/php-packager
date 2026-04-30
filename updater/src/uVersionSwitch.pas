
unit uVersionSwitch;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

procedure WriteCurrentVersionPointer(const RootDir, Version: string);
function ReadCurrentVersionPointer(const RootDir: string): string;

implementation

procedure WriteCurrentVersionPointer(const RootDir, Version: string);
var
  Path: string;
  F: TextFile;
begin
  ForceDirectories(RootDir);
  Path := IncludeTrailingPathDelimiter(RootDir) + 'current.txt';
  AssignFile(F, Path);
  Rewrite(F);
  try
    WriteLn(F, Version);
  finally
    CloseFile(F);
  end;
end;

function ReadCurrentVersionPointer(const RootDir: string): string;
var
  Path: string;
  F: TextFile;
begin
  Result := '';
  Path := IncludeTrailingPathDelimiter(RootDir) + 'current.txt';
  if not FileExists(Path) then
    Exit;
  AssignFile(F, Path);
  Reset(F);
  try
    if not EOF(F) then
      ReadLn(F, Result);
  finally
    CloseFile(F);
  end;
end;

end.
