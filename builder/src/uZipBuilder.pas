
unit uZipBuilder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, zipper;

type
  TZipBuilder = class
  public
    class procedure ZipDirectory(const SourceDir, ZipPath: string);
  end;

implementation

uses
  fpjson, jsonparser;

function WildcardMatch(const Text, Pattern: string): Boolean;
var
  TLen, PLen: Integer;

  function MatchFrom(TPos, PPos: Integer): Boolean;
  begin
    while PPos <= PLen do
    begin
      case Pattern[PPos] of
        '*':
          begin
            Inc(PPos);
            if PPos > PLen then
              Exit(True);
            while TPos <= TLen do
            begin
              if MatchFrom(TPos, PPos) then
                Exit(True);
              Inc(TPos);
            end;
            Exit(False);
          end;
        '?':
          begin
            if TPos > TLen then
              Exit(False);
            Inc(TPos);
            Inc(PPos);
          end;
      else
        begin
          if (TPos > TLen) or (Text[TPos] <> Pattern[PPos]) then
            Exit(False);
          Inc(TPos);
          Inc(PPos);
        end;
      end;
    end;

    Result := TPos > TLen;
  end;

begin
  TLen := Length(Text);
  PLen := Length(Pattern);
  Result := MatchFrom(1, 1);
end;

function NormalizeZipPath(const S: string): string;
begin
  Result := StringReplace(Trim(S), '\\', '/', [rfReplaceAll]);
  while (Result <> '') and ((Result[1] = '/') or (Result[1] = '.')) do
  begin
    if (Length(Result) >= 2) and (Copy(Result, 1, 2) = './') then
      Delete(Result, 1, 2)
    else if Result[1] = '/' then
      Delete(Result, 1, 1)
    else
      Break;
  end;
  while (Result <> '') and (Result[Length(Result)] = '/') do
    Delete(Result, Length(Result), 1);
end;

function LoadExcludePatterns(const SourceDir: string): TStringList;
var
  ManifestPath: string;
  Raw: TStringList;
  Root: TJSONData;
  Obj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Pattern: string;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.Duplicates := dupIgnore;

  ManifestPath := IncludeTrailingPathDelimiter(SourceDir) + 'manifest.json';
  if not FileExists(ManifestPath) then
    Exit;

  Raw := TStringList.Create;
  Root := nil;
  try
    Raw.LoadFromFile(ManifestPath);
    Root := GetJSON(Raw.Text);
    if (Root <> nil) and (Root.JSONType = jtObject) then
    begin
      Obj := TJSONObject(Root);
      Arr := Obj.Arrays['exclude'];
      if Arr <> nil then
        for I := 0 to Arr.Count - 1 do
        begin
          Pattern := NormalizeZipPath(Arr.Strings[I]);
          if Pattern <> '' then
            Result.Add(Pattern);
        end;
    end;
  finally
    Root.Free;
    Raw.Free;
  end;
end;

function PathHasSegment(const RelPath, Segment: string): Boolean;
var
  SegNeedle, NormPath: string;
begin
  SegNeedle := '/' + LowerCase(Segment) + '/';
  NormPath := '/' + LowerCase(NormalizeZipPath(RelPath)) + '/';
  Result := Pos(SegNeedle, NormPath) > 0;
end;

function IsExcluded(const RelPath: string; Excludes: TStrings): Boolean;
var
  I: Integer;
  Pattern, PNorm, RNorm: string;
begin
  Result := False;
  if (Excludes = nil) or (Excludes.Count = 0) then
    Exit;

  RNorm := NormalizeZipPath(RelPath);
  if RNorm = '' then
    Exit;

  for I := 0 to Excludes.Count - 1 do
  begin
    Pattern := Trim(Excludes[I]);
    if Pattern = '' then
      Continue;

    PNorm := NormalizeZipPath(Pattern);
    if PNorm = '' then
      Continue;

    if (Pos('*', PNorm) > 0) or (Pos('?', PNorm) > 0) then
    begin
      if WildcardMatch(LowerCase(RNorm), LowerCase(PNorm)) then
        Exit(True);
      Continue;
    end;

    if Pos('/', PNorm) > 0 then
    begin
      if (LowerCase(RNorm) = LowerCase(PNorm)) or
         (Pos(LowerCase(PNorm) + '/', LowerCase(RNorm) + '/') = 1) then
        Exit(True);
      Continue;
    end;

    if PathHasSegment(RNorm, PNorm) then
      Exit(True);
  end;
end;

class procedure TZipBuilder.ZipDirectory(const SourceDir, ZipPath: string);
var
  Z: TZipper;
  Excludes: TStringList;

  procedure AddTree(const BaseDir, CurrentDir: string);
  var
    SR: TSearchRec;
    FullPath, RelPath, RelPathNorm: string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(CurrentDir) + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then
          Continue;
        FullPath := IncludeTrailingPathDelimiter(CurrentDir) + SR.Name;
        RelPath := StringReplace(FullPath, IncludeTrailingPathDelimiter(BaseDir), '', []);
        RelPathNorm := NormalizeZipPath(RelPath);

        if (SR.Attr and faDirectory) = faDirectory then
        begin
          if not IsExcluded(RelPathNorm, Excludes) then
            AddTree(BaseDir, FullPath);
        end
        else
        begin
          if not IsExcluded(RelPathNorm, Excludes) then
            Z.Entries.AddFileEntry(FullPath, RelPathNorm);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;

begin
  if FileExists(ZipPath) then
    DeleteFile(ZipPath);

  ForceDirectories(ExtractFileDir(ZipPath));

  Excludes := LoadExcludePatterns(ExpandFileName(SourceDir));
  Z := TZipper.Create;
  try
    Z.FileName := ZipPath;
    AddTree(ExpandFileName(SourceDir), ExpandFileName(SourceDir));
    Z.ZipAllFiles;
  finally
    Z.Free;
    Excludes.Free;
  end;
end;

end.
