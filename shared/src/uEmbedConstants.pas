
unit uEmbedConstants;

{$mode objfpc}{$H+}

interface

const
  EMBED_MAGIC: AnsiString = 'PHPPACK1';
  EMBED_FOOTER_VERSION = 1;
  EMBED_SHA256_HEX_LEN = 64;
  EMBED_APP_VERSION_LEN = 32;
  EMBED_RESERVED_LEN = 64;

implementation

end.
