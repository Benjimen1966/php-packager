
unit uEmbedFooter;

{$mode objfpc}{$H+}
{$packrecords c}

interface

uses
  Classes, SysUtils, uEmbedConstants;

type
  TEmbedFooter = packed record
    Magic: array[0..7] of AnsiChar;
    FooterVersion: LongInt;
    PayloadOffset: Int64;
    PayloadSize: Int64;
    ManifestOffset: Int64;
    ManifestSize: Int64;
    PayloadSha256Hex: array[0..EMBED_SHA256_HEX_LEN - 1] of AnsiChar;
    AppVersion: array[0..EMBED_APP_VERSION_LEN - 1] of AnsiChar;
    Reserved: array[0..EMBED_RESERVED_LEN - 1] of Byte;
  end;

procedure InitFooter(out Footer: TEmbedFooter; const PayloadOffset, PayloadSize: Int64;
  const PayloadSha256Hex, AppVersion: string);
function FooterMagicOk(const Footer: TEmbedFooter): Boolean;
function FooterPayloadHash(const Footer: TEmbedFooter): string;
function FooterAppVersion(const Footer: TEmbedFooter): string;
procedure WriteFooterToStream(Stream: TStream; const Footer: TEmbedFooter);
function ReadFooterFromExe(const ExePath: string; out Footer: TEmbedFooter): Boolean;

implementation

procedure FillAnsiCharArray(var Dest; DestLen: Integer; const S: string);
var
  P: PAnsiChar;
  I, L: Integer;
begin
  FillChar(Dest, DestLen, 0);
  L := Length(S);
  if L > DestLen then
    L := DestLen;
  P := @Dest;
  for I := 1 to L do
    P[I - 1] := AnsiChar(S[I]);
end;

function TrimAnsiCharArray(const Src; SrcLen: Integer): string;
var
  P: PAnsiChar;
  I: Integer;
begin
  Result := '';
  P := @Src;
  for I := 0 to SrcLen - 1 do
  begin
    if P[I] = #0 then
      Break;
    Result := Result + Char(P[I]);
  end;
end;

procedure InitFooter(out Footer: TEmbedFooter; const PayloadOffset, PayloadSize: Int64;
  const PayloadSha256Hex, AppVersion: string);
begin
  FillChar(Footer, SizeOf(Footer), 0);
  Move(EMBED_MAGIC[1], Footer.Magic[0], Length(EMBED_MAGIC));
  Footer.FooterVersion := EMBED_FOOTER_VERSION;
  Footer.PayloadOffset := PayloadOffset;
  Footer.PayloadSize := PayloadSize;
  Footer.ManifestOffset := 0;
  Footer.ManifestSize := 0;
  FillAnsiCharArray(Footer.PayloadSha256Hex, EMBED_SHA256_HEX_LEN, LowerCase(PayloadSha256Hex));
  FillAnsiCharArray(Footer.AppVersion, EMBED_APP_VERSION_LEN, AppVersion);
end;

function FooterMagicOk(const Footer: TEmbedFooter): Boolean;
var
  S: string;
begin
  SetString(S, PAnsiChar(@Footer.Magic[0]), 8);
  Result := S = EMBED_MAGIC;
end;

function FooterPayloadHash(const Footer: TEmbedFooter): string;
begin
  Result := TrimAnsiCharArray(Footer.PayloadSha256Hex, EMBED_SHA256_HEX_LEN);
end;

function FooterAppVersion(const Footer: TEmbedFooter): string;
begin
  Result := TrimAnsiCharArray(Footer.AppVersion, EMBED_APP_VERSION_LEN);
end;

procedure WriteFooterToStream(Stream: TStream; const Footer: TEmbedFooter);
begin
  Stream.WriteBuffer(Footer, SizeOf(Footer));
end;

function ReadFooterFromExe(const ExePath: string; out Footer: TEmbedFooter): Boolean;
var
  FS: TFileStream;
begin
  Result := False;
  FillChar(Footer, SizeOf(Footer), 0);
  if not FileExists(ExePath) then
    Exit;

  FS := TFileStream.Create(ExePath, fmOpenRead or fmShareDenyWrite);
  try
    if FS.Size < SizeOf(TEmbedFooter) then
      Exit;
    FS.Seek(-SizeOf(TEmbedFooter), soEnd);
    FS.ReadBuffer(Footer, SizeOf(TEmbedFooter));
    Result := FooterMagicOk(Footer);
  finally
    FS.Free;
  end;
end;

end.
