
unit uExtractionValidation;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

procedure RequireFileExists(const FileName: string; const FriendlyName: string);
procedure RequireDirectoryExists(const DirName: string; const FriendlyName: string);

implementation

procedure RequireFileExists(const FileName: string; const FriendlyName: string);
begin
  if not FileExists(FileName) then
    raise Exception.Create(FriendlyName + ' not found: ' + FileName);
end;

procedure RequireDirectoryExists(const DirName: string; const FriendlyName: string);
begin
  if not DirectoryExists(DirName) then
    raise Exception.Create(FriendlyName + ' not found: ' + DirName);
end;

end.
