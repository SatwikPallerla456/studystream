#define AppVersion "1.0.0-preview.1"
[Setup]
AppId={{E97D1443-FB80-42AF-AE23-717509E46351}
AppName=Tangerine
AppVersion={#AppVersion}
AppPublisher=Tangerine
DefaultDirName={autopf}\Tangerine
DefaultGroupName=Tangerine
OutputDir=..\dist
OutputBaseFilename=Tangerine-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\study_stream.exe
SetupIconFile=..\assets\brand\tangerine.ico
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\dist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
[Icons]
Name: "{group}\Tangerine"; Filename: "{app}\study_stream.exe"
[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ runtime..."; Flags: waituntilterminated
Filename: "{app}\study_stream.exe"; Description: "Launch Tangerine"; Flags: nowait postinstall skipifsilent
