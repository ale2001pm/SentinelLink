[Setup]
AppName=SentinelLink
AppVersion=1.0.0
AppPublisher=SentinelLink
DefaultDirName={autopf}\SentinelLink
DefaultGroupName=SentinelLink
OutputDir=installer_output
OutputBaseFilename=SentinelLink-Setup-v1.0.0
SetupIconFile=sentinellink_frontend\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
LicenseFile=
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"; Flags: unchecked

[Files]
Source: "sentinellink_frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SentinelLink"; Filename: "{app}\sentinellink_frontend.exe"; IconFilename: "{app}\sentinellink_frontend.exe"
Name: "{group}\Desinstalar SentinelLink"; Filename: "{uninstallexe}"
Name: "{commondesktop}\SentinelLink"; Filename: "{app}\sentinellink_frontend.exe"; IconFilename: "{app}\sentinellink_frontend.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\sentinellink_frontend.exe"; Description: "Iniciar SentinelLink"; Flags: nowait postinstall skipifsilent
