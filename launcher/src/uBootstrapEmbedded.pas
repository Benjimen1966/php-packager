
unit uBootstrapEmbedded;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uLogger;

function BootstrapEmbeddedSelf(const AppName: string; Logger: TLogger): string;

implementation

uses
  uEmbeddedExtractor;

function BootstrapEmbeddedSelf(const AppName: string; Logger: TLogger): string;
begin
  Result := TEmbeddedExtractor.EnsureExtracted(ParamStr(0), AppName, Logger);
end;

end.
