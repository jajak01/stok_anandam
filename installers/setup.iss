#define MyAppName "Movva"
#define MyAppFullBrand "Movva by Anandam.id"
#define MyAppVersion "1.1.39"
#define MyAppPublisher "AnandamComputer"
#define MyAppExeName "stok_anandam.exe"

[Setup]
OutputDir=D:\Idos\Coding\Flutter\ReleseAPP\Output
OutputBaseFilename=Movva_Setup_v1.1.39

AppName={#MyAppFullBrand}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AppSupportURL=https://www.anandamcomputer.com

PrivilegesRequired=admin
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "D:\Idos\Coding\Flutter\stok_anandam\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\Idos\Coding\Flutter\stok_anandam\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\Idos\Coding\Flutter\stok_anandam\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "D:\Idos\Coding\Flutter\stok_anandam\installers\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppFullBrand}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppFullBrand}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /passive /norestart"; Check: VCRedistNeedsInstall; StatusMsg: "Menginstal Microsoft Visual C++ Redistributable..."
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppFullBrand, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
    Result := False
  else
    Result := True;
end;

