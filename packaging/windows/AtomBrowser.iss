[Setup]
AppId=AtomBrowser.Windows.x64
AppName=Atom Browser
AppVersion=0.1.0
AppVerName=Atom Browser 0.1.0 Alpha
AppPublisher=Atom Browser Project
DefaultDirName={autopf}\Atom Browser
DefaultGroupName=Atom Browser
PrivilegesRequired=admin
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.19041
SetupIconFile=assets\atom_browser.ico
UninstallDisplayIcon={app}\chrome.exe
OutputDir=output
OutputBaseFilename=AtomBrowserSetup-0.1.0-alpha-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Create desktop shortcut"; Flags: unchecked

[Files]
Source: "staging\AtomBrowser\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Atom Browser"; Filename: "{app}\chrome.exe"
Name: "{commondesktop}\Atom Browser"; Filename: "{app}\chrome.exe"; Tasks: desktopicon

[Registry]
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser"; ValueType: string; ValueData: "Atom Browser"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\DefaultIcon"; ValueType: string; ValueData: "{app}\chrome.exe,0"
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\shell\open\command"; ValueType: string; ValueData: """{app}\chrome.exe"""
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "Atom Browser"
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "Atom Browser"
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\Capabilities\UrlAssociations"; ValueType: string; ValueName: "http"; ValueData: "AtomHTM"
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\Capabilities\UrlAssociations"; ValueType: string; ValueName: "https"; ValueData: "AtomHTM"
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\Capabilities\FileAssociations"; ValueType: string; ValueName: ".html"; ValueData: "AtomHTM"
Root: HKLM; Subkey: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\Capabilities\FileAssociations"; ValueType: string; ValueName: ".htm"; ValueData: "AtomHTM"
Root: HKLM; Subkey: "SOFTWARE\RegisteredApplications"; ValueType: string; ValueName: "Atom Browser"; ValueData: "SOFTWARE\Clients\StartMenuInternet\Atom Browser\Capabilities"; Flags: uninsdeletevalue
Root: HKLM; Subkey: "SOFTWARE\Classes\AtomHTM"; ValueType: string; ValueData: "Atom Browser HTML Document"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Classes\AtomHTM"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKLM; Subkey: "SOFTWARE\Classes\AtomHTM\DefaultIcon"; ValueType: string; ValueData: "{app}\chrome.exe,0"
Root: HKLM; Subkey: "SOFTWARE\Classes\AtomHTM\shell\open\command"; ValueType: string; ValueData: """{app}\chrome.exe"" --single-argument ""%1"""

[Run]

; Allow Windows AppContainer processes to read and execute browser files
Filename: "{sys}\icacls.exe"; Parameters: """{app}"" /grant *S-1-15-2-1:(OI)(CI)(RX) /T /C"; Flags: runhidden waituntilterminated

; Allow restricted AppContainer processes to read and execute browser files
Filename: "{sys}\icacls.exe"; Parameters: """{app}"" /grant *S-1-15-2-2:(OI)(CI)(RX) /T /C"; Flags: runhidden waituntilterminated

; Launch Atom Browser after installation
Filename: "{app}\chrome.exe"; Description: "Launch Atom Browser"; Flags: nowait postinstall skipifsilent
