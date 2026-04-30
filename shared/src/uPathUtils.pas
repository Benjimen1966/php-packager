
unit uPathUtils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function GetLocalAppDataDir: string;
function CombinePath(const A, B: string): string;
function EnsureDir(const Dir: string): string;
function GetAppDataRoot(const AppName: string): string;

implementation

function GetLocalAppDataDir: string;
begin
  Result := GetEnvironmentVariable('LOCALAPPDATA');
  if Result = '' then
    Result := GetTempDir(False);
end;

function CombinePath(const A, B: string): string;
begin
  Result := IncludeTrailingPathDelimiter(A) + B;
end;

function EnsureDir(const Dir: string): string;
begin
  ForceDirectories(Dir);
  Result := Dir;
end;

function GetAppDataRoot(const AppName: string): string;
begin
  Result := EnsureDir(CombinePath(GetLocalAppDataDir, AppName));
end;

end.
