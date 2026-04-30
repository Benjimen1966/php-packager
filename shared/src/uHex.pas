
unit uHex;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function BytesToHex(const Buffer; Count: Integer): string;

implementation

function BytesToHex(const Buffer; Count: Integer): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  P: PByte;
  I: Integer;
begin
  SetLength(Result, Count * 2);
  P := @Buffer;
  for I := 0 to Count - 1 do
  begin
    Result[(I * 2) + 1] := HexChars[P^ shr 4];
    Result[(I * 2) + 2] := HexChars[P^ and $0F];
    Inc(P);
  end;
end;

end.
