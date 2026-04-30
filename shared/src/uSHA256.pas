
unit uSHA256;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uHex;

function SHA256OfStreamHex(Stream: TStream): string;
function SHA256OfFileHex(const FileName: string): string;

implementation

type
  TSHA256Context = record
    State: array[0..7] of LongWord;
    Data: array[0..63] of Byte;
    DataLen: LongWord;
    BitLen: QWord;
  end;

  TSHA256Digest = array[0..31] of Byte;

const
  K: array[0..63] of LongWord = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

function ROTR(const X: LongWord; N: Byte): LongWord; inline;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

function Ch(const X, Y, Z: LongWord): LongWord; inline;
begin
  Result := (X and Y) xor ((not X) and Z);
end;

function Maj(const X, Y, Z: LongWord): LongWord; inline;
begin
  Result := (X and Y) xor (X and Z) xor (Y and Z);
end;

function Sigma0(const X: LongWord): LongWord; inline;
begin
  Result := ROTR(X, 2) xor ROTR(X, 13) xor ROTR(X, 22);
end;

function Sigma1(const X: LongWord): LongWord; inline;
begin
  Result := ROTR(X, 6) xor ROTR(X, 11) xor ROTR(X, 25);
end;

function Gamma0(const X: LongWord): LongWord; inline;
begin
  Result := ROTR(X, 7) xor ROTR(X, 18) xor (X shr 3);
end;

function Gamma1(const X: LongWord): LongWord; inline;
begin
  Result := ROTR(X, 17) xor ROTR(X, 19) xor (X shr 10);
end;

procedure SHA256Transform(var Ctx: TSHA256Context; const Data: array of Byte);
var
  A, B, C, D, E, F, G, H: LongWord;
  T1, T2: LongWord;
  M: array[0..63] of LongWord;
  I, J: Integer;
begin
  J := 0;
  for I := 0 to 15 do
  begin
    M[I] := (LongWord(Data[J]) shl 24) or (LongWord(Data[J + 1]) shl 16) or
      (LongWord(Data[J + 2]) shl 8) or LongWord(Data[J + 3]);
    Inc(J, 4);
  end;

  for I := 16 to 63 do
    M[I] := Gamma1(M[I - 2]) + M[I - 7] + Gamma0(M[I - 15]) + M[I - 16];

  A := Ctx.State[0];
  B := Ctx.State[1];
  C := Ctx.State[2];
  D := Ctx.State[3];
  E := Ctx.State[4];
  F := Ctx.State[5];
  G := Ctx.State[6];
  H := Ctx.State[7];

  for I := 0 to 63 do
  begin
    T1 := H + Sigma1(E) + Ch(E, F, G) + K[I] + M[I];
    T2 := Sigma0(A) + Maj(A, B, C);
    H := G;
    G := F;
    F := E;
    E := D + T1;
    D := C;
    C := B;
    B := A;
    A := T1 + T2;
  end;

  Ctx.State[0] := Ctx.State[0] + A;
  Ctx.State[1] := Ctx.State[1] + B;
  Ctx.State[2] := Ctx.State[2] + C;
  Ctx.State[3] := Ctx.State[3] + D;
  Ctx.State[4] := Ctx.State[4] + E;
  Ctx.State[5] := Ctx.State[5] + F;
  Ctx.State[6] := Ctx.State[6] + G;
  Ctx.State[7] := Ctx.State[7] + H;
end;

procedure SHA256Init(var Ctx: TSHA256Context);
begin
  Ctx.DataLen := 0;
  Ctx.BitLen := 0;
  Ctx.State[0] := $6a09e667;
  Ctx.State[1] := $bb67ae85;
  Ctx.State[2] := $3c6ef372;
  Ctx.State[3] := $a54ff53a;
  Ctx.State[4] := $510e527f;
  Ctx.State[5] := $9b05688c;
  Ctx.State[6] := $1f83d9ab;
  Ctx.State[7] := $5be0cd19;
end;

procedure SHA256Update(var Ctx: TSHA256Context; const Input; Len: LongWord);
var
  P: PByte;
  I: LongWord;
begin
  P := @Input;
  for I := 0 to Len - 1 do
  begin
    Ctx.Data[Ctx.DataLen] := P[I];
    Inc(Ctx.DataLen);
    if Ctx.DataLen = 64 then
    begin
      SHA256Transform(Ctx, Ctx.Data);
      Inc(Ctx.BitLen, 512);
      Ctx.DataLen := 0;
    end;
  end;
end;

procedure SHA256Final(var Ctx: TSHA256Context; out Digest: TSHA256Digest);
var
  I: Integer;
begin
  I := Ctx.DataLen;

  if Ctx.DataLen < 56 then
  begin
    Ctx.Data[I] := $80;
    Inc(I);
    while I < 56 do
    begin
      Ctx.Data[I] := 0;
      Inc(I);
    end;
  end
  else
  begin
    Ctx.Data[I] := $80;
    Inc(I);
    while I < 64 do
    begin
      Ctx.Data[I] := 0;
      Inc(I);
    end;
    SHA256Transform(Ctx, Ctx.Data);
    FillChar(Ctx.Data, 56, 0);
  end;

  Inc(Ctx.BitLen, QWord(Ctx.DataLen) * 8);
  Ctx.Data[63] := Byte(Ctx.BitLen);
  Ctx.Data[62] := Byte(Ctx.BitLen shr 8);
  Ctx.Data[61] := Byte(Ctx.BitLen shr 16);
  Ctx.Data[60] := Byte(Ctx.BitLen shr 24);
  Ctx.Data[59] := Byte(Ctx.BitLen shr 32);
  Ctx.Data[58] := Byte(Ctx.BitLen shr 40);
  Ctx.Data[57] := Byte(Ctx.BitLen shr 48);
  Ctx.Data[56] := Byte(Ctx.BitLen shr 56);
  SHA256Transform(Ctx, Ctx.Data);

  for I := 0 to 3 do
  begin
    Digest[I] := Byte(Ctx.State[0] shr (24 - I * 8));
    Digest[I + 4] := Byte(Ctx.State[1] shr (24 - I * 8));
    Digest[I + 8] := Byte(Ctx.State[2] shr (24 - I * 8));
    Digest[I + 12] := Byte(Ctx.State[3] shr (24 - I * 8));
    Digest[I + 16] := Byte(Ctx.State[4] shr (24 - I * 8));
    Digest[I + 20] := Byte(Ctx.State[5] shr (24 - I * 8));
    Digest[I + 24] := Byte(Ctx.State[6] shr (24 - I * 8));
    Digest[I + 28] := Byte(Ctx.State[7] shr (24 - I * 8));
  end;
end;

function SHA256OfStreamHex(Stream: TStream): string;
var
  Ctx: TSHA256Context;
  Digest: TSHA256Digest;
  Buffer: array[0..65535] of Byte;
  ReadCount: Integer;
begin
  SHA256Init(Ctx);
  Stream.Position := 0;
  repeat
    ReadCount := Stream.Read(Buffer, SizeOf(Buffer));
    if ReadCount > 0 then
      SHA256Update(Ctx, Buffer, ReadCount);
  until ReadCount = 0;
  SHA256Final(Ctx, Digest);
  Result := LowerCase(BytesToHex(Digest, SizeOf(Digest)));
end;

function SHA256OfFileHex(const FileName: string): string;
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := SHA256OfStreamHex(FS);
  finally
    FS.Free;
  end;
end;

end.
