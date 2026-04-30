#ifndef BuildSourceDir
	#define BuildSourceDir "..\\dist"
#endif

[Setup]
AppName=Mywbstd
AppVersion=1.0.0
DefaultDirName={localappdata}\Programs\Mywbstd
DefaultGroupName=Mywbstd
UninstallDisplayIcon={app}\Mywbstd.exe
OutputBaseFilename=MywbstdSetup
Compression=lzma
SolidCompression=yes

[Files]
Source: "{#BuildSourceDir}\\Mywbstd.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildSourceDir}\\updater.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Mywbstd"; Filename: "{app}\Mywbstd.exe"
Name: "{autodesktop}\Mywbstd"; Filename: "{app}\Mywbstd.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\Mywbstd.exe"; Description: "Launch Mywbstd"; Flags: nowait postinstall skipifsilent
