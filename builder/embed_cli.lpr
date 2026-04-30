
program embed_cli;

{$mode objfpc}{$H+}

uses
  SysUtils, uEmbeddedBuilder, uZipBuilder, uEmbedFooter, uSHA256;

{$R *.res}

begin
  if (ParamCount <> 4) and (ParamCount <> 5) then
  begin
    Writeln('Usage: embed_cli <launcher_stub.exe> <staging_dir> <output.exe> <app_version> [work_dir]');
    Halt(1);
  end;

  try
    if ParamCount = 5 then
      TEmbeddedBuilder.BuildEmbeddedExe(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5))
    else
      TEmbeddedBuilder.BuildEmbeddedExe(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
    Writeln('Embedded EXE created: ', ParamStr(3));
  except
    on E: Exception do
    begin
      Writeln('ERROR: ', E.Message);
      Halt(2);
    end;
  end;
end.
