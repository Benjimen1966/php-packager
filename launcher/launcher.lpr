
program launcher;

{$mode objfpc}{$H+}

uses
  SysUtils,
  uLogger,
  uPathUtils, uSHA256, uEmbedFooter, uHex,
  uBootstrapEmbedded,
  uLauncherConfig, uEmbeddedExtractor, uRuntimeBootstrap;

var
  Logger: TLogger;
  AppRoot, ExtractedRoot: string;
begin
  AppRoot := GetAppDataRoot(DEFAULT_APP_NAME);
  Logger := TLogger.Create(IncludeTrailingPathDelimiter(AppRoot) + 'logs\startup.log');
  try
    Logger.Info('Launcher start. Self=' + ParamStr(0));
    ExtractedRoot := BootstrapEmbeddedSelf(DEFAULT_APP_NAME, Logger);
    Logger.Info('Embedded payload available at: ' + ExtractedRoot);
    StartEmbeddedRuntime(ExtractedRoot, Logger);
    Writeln('Application launched from: ' + ExtractedRoot);
  except
    on E: Exception do
    begin
      Logger.Error(E.Message);
      Writeln('ERROR: ' + E.Message);
      Halt(1);
    end;
  end;
  Logger.Free;
end.
