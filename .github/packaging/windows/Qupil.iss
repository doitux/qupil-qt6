; QUPIL_NATIVE_ARTIFACTS_V1
; Windows test installer for Qupil CI builds.
; Values are supplied by the GitHub Actions job as environment variables.

[Setup]
AppId=Qupil.Qt6
AppName=Qupil
AppVersion={#%QUPIL_INSTALLER_VERSION}
AppPublisher=Qupil
DefaultDirName={localappdata}\Programs\Qupil
DefaultGroupName=Qupil
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#%QUPIL_INSTALLER_OUTPUT_DIR}
OutputBaseFilename={#%QUPIL_INSTALLER_BASE_NAME}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\qupil.exe

[Files]
Source: "{#%QUPIL_INSTALLER_SOURCE_DIR}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Qupil"; Filename: "{app}\qupil.exe"

[Run]
Filename: "{app}\qupil.exe"; Description: "Qupil starten"; Flags: nowait postinstall skipifsilent
