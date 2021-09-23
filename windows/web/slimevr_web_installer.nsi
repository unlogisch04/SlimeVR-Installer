!include x64.nsh 		; For RunningX64 check
!include LogicLib.nsh	; For conditional operators

# Define name of installer
Name SlimeVR Installer

SpaceTexts none # Don't show required disk space since we don't know for sure
SetOverwrite on
SetCompressor lzma  # Use LZMA Compression algorithm, compression quality is better.

OutFile "slimevr_web_installer.exe"

# Define installation directory
InstallDir "$LOCALAPPDATA\Programs\SlimeVR Server" ; $InstDir default value. Defaults to user's local appdata to avoid asking admin rights

# For removing Start Menu shortcut in Windows 7
RequestExecutionLevel user

Page Directory ; This page might change $InstDir
Page InstFiles

# Detect Steam and SteamVR installation and prevent installation if none found
Var /GLOBAL SteamPath
Function .onInit
    ${If} ${RunningX64}
        ReadRegStr $0 HKLM SOFTWARE\WOW6432Node\Valve\Steam InstallPath
    ${Else}
        ReadRegStr $0 HKLM SOFTWARE\Valve\Steam InstallPath
    ${EndIf}
    ${If} $0 == ""
        MessageBox MB_OK "No Steam installation folder detected."
        Abort
    ${EndIf}
    StrCpy $SteamPath $0
FunctionEnd

# Detect Steam and SteamVR installation and just write path that we need to remove during uninstall (if present)
Function un.onInit
    ${If} ${RunningX64}
        ReadRegStr $0 HKLM SOFTWARE\WOW6432Node\Valve\Steam InstallPath
    ${Else}
        ReadRegStr $0 HKLM SOFTWARE\Valve\Steam InstallPath
    ${EndIf}
    StrCpy $SteamPath $0
FunctionEnd

# Clean up on exit
Function .onGUIEnd
    Delete "$TEMP\slimevr-openvr-driver-win64.zip"
    Delete "$TEMP\SlimeVR.zip"
    Delete "$TEMP\OpenJDK11U-jre_x64_windows_hotspot_11.0.12_7.zip"
    Delete "$TEMP\OpenJDK11U-jre_x86-32_windows_hotspot_11.0.12_7.zip"
    RMDir /r "$TEMP\slimevr-openvr-driver-win64"
    RMDir /r "$TEMP\SlimeVR"
    RMDir /r "$TEMP\OpenJDK11U-jre_x86-32_windows_hotspot_11.0.12_7"
    RMDir /r "$TEMP\OpenJDK11U-jre_x64_windows_hotspot_11.0.12_7"
FunctionEnd

!macro cleanInstDir un
Function ${un}cleanInstDir
    Delete "$INSTDIR\uninstall.exe"
    Delete "$INSTDIR\run.bat"
    Delete "$INSTDIR\run.ico"
    Delete "$INSTDIR\slimevr.jar"
    Delete "$INSTDIR\firewall.bat"
    Delete "$INSTDIR\MagnetoLib.dll"
    Delete "$INSTDIR\steamvr.ps1"
    Delete "$INSTDIR\log*"
    Delete "$INSTDIR\vrconfig.yml"

    RMdir /r "$INSTDIR\jre"
    RMdir /r "$INSTDIR\driver"
    RMDir /r "$INSTDIR\logs"

    RMDir $INSTDIR
FunctionEnd
!macroend

!insertmacro cleanInstDir ""
!insertmacro cleanInstDir "un."

# InstFiles section start
Section
    Var /GLOBAL DownloadedJreFile
    DetailPrint "Downloading Java JRE..."
    ${If} ${RunningX64}
        NScurl::http GET "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.12%2B7/OpenJDK11U-jre_x64_windows_hotspot_11.0.12_7.zip" "$TEMP\OpenJDK11U-jre_x64_windows_hotspot_11.0.12_7.zip" /CANCEL /RESUME /END
        StrCpy $DownloadedJreFile "OpenJDK11U-jre_x64_windows_hotspot_11.0.12_7"
    ${Else}
        NScurl::http GET "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.12%2B7/OpenJDK11U-jre_x86-32_windows_hotspot_11.0.12_7.zip" "$TEMP\OpenJDK11U-jre_x86-32_windows_hotspot_11.0.12_7.zip" /CANCEL /RESUME /END
        StrCpy $DownloadedJreFile "OpenJDK11U-jre_x86-32_windows_hotspot_11.0.12_7"
    ${EndIf}
    Pop $0 ; Status text ("OK" for success)
    ${If} $0 != "OK"
        Abort "Failed to download Java JRE."
    ${EndIf}
    DetailPrint "Downloaded!"

    DetailPrint "Downloading SlimeVR Driver..."
    NScurl::http GET "https://github.com/SlimeVR/SlimeVR-OpenVR-Driver/releases/latest/download/slimevr-openvr-driver-win64.zip" "$TEMP\slimevr-openvr-driver-win64.zip" /CANCEL /RESUME /END
    Pop $0 ; Status text ("OK" for success)
    ${If} $0 != "OK"
        Abort "Failed to download SlimeVR Driver."
    ${EndIf}
    DetailPrint "Downloaded!"

    DetailPrint "Downloading SlimeVR Server..."
    NScurl::http GET "https://github.com/SlimeVR/SlimeVR-Server/releases/latest/download/SlimeVR.zip" "$TEMP\SlimeVR.zip" /CANCEL /RESUME /END
    Pop $0 ; Status text ("OK" for success)
    ${If} $0 != "OK"
        Abort "Failed to download SlimeVR Server."
    ${EndIf}
    DetailPrint "Downloaded!"

    DetailPrint "Unpacking downloaded files..."
    nsisunz::Unzip "$TEMP\slimevr-openvr-driver-win64.zip" "$TEMP\slimevr-openvr-driver-win64\"
    Pop $0

    nsisunz::Unzip "$TEMP\SlimeVR.zip" "$TEMP\SlimeVR\"
    Pop $0

    nsisunz::Unzip "$TEMP\$DownloadedJreFile.zip" "$TEMP\$DownloadedJreFile\"
    Pop $0

    # Set the installation directory as the destination for the following actions
    SetOutPath $INSTDIR

    DetailPrint "Copying SlimeVR Server and SlimeVR Driver to installation folder..."
    CopyFiles /SILENT "$TEMP\SlimeVR\SlimeVR\*" $INSTDIR
    CopyFiles /SILENT "$TEMP\slimevr-openvr-driver-win64\slimevr\*" "$INSTDIR\driver"
    CopyFiles /SILENT "$TEMP\$DownloadedJreFile\jdk-11.0.12+7-jre\*" "$INSTDIR\jre"

    # Include modified run.bat that will run bundled JRE
    File "run.bat"
    File "run.ico"
    # Include SteamVR powershell script to register/unregister driver
    File "steamvr.ps1"

    DetailPrint "Registering SlimeVR Driver..."
    ${If} ${RunningX64}
        ExecWait "powershell -ExecutionPolicy Bypass -File $\"$INSTDIR\steamvr.ps1$\" $\"$SteamPath$\" $\"$INSTDIR\driver$\" $\"adddriver$\" $\"win64$\"" $0
    ${Else}
        ExecWait "powershell -ExecutionPolicy Bypass -File $\"$INSTDIR\steamvr.ps1$\" $\"$SteamPath$\" $\"$INSTDIR\driver$\" $\"adddriver$\" $\"win32$\"" $0
    ${EndIf}
    ${If} $0 != 0
        Call cleanInstDir
        Abort "Failed to register SlimeVR Driver. Make sure you have SteamVR installed."
    ${EndIf}

    # Point the new shortcut at the program uninstaller
    DetailPrint "Creating shortcuts..."
    CreateShortcut "$SMPROGRAMS\Uninstall SlimeVR Server.lnk" "$INSTDIR\uninstall.exe"
    CreateShortcut "$SMPROGRAMS\Run SlimeVR Server.lnk" "$INSTDIR\run.bat" "" "$INSTDIR\run.ico"
    CreateShortcut "$DESKTOP\Run SlimeVR Server.lnk" "$INSTDIR\run.bat" "" "$INSTDIR\run.ico"

    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SlimeVR" \
                    "DisplayName" "SlimeVR"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SlimeVR" \
                    "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SlimeVR" \
                    "DisplayIcon" "$\"$INSTDIR\run.ico$\""

    # Create the uninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"

    DetailPrint "Done."
SectionEnd
# InstFiles section end

# Uninstaller section start
Section "uninstall"
    ${If} ${RunningX64}
        ExecWait "powershell -ExecutionPolicy Bypass -File $\"$INSTDIR\steamvr.ps1$\" $\"$SteamPath$\" $\"$INSTDIR\driver$\" $\"removedriver$\" $\"win64$\"" $0
    ${Else}
        ExecWait "powershell -ExecutionPolicy Bypass -File $\"$INSTDIR\steamvr.ps1$\" $\"$SteamPath$\" $\"$INSTDIR\driver$\" $\"removedriver$\" $\"win32$\"" $0
    ${EndIf}

    # Remove the shortcuts
    Delete "$SMPROGRAMS\Uninstall SlimeVR Server.lnk"
    Delete "$SMPROGRAMS\Run SlimeVR Server.lnk"
    Delete "$DESKTOP\Run SlimeVR Server.lnk"

    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SlimeVR"

    Call un.cleanInstDir

    DetailPrint "Done."
SectionEnd
# Uninstaller section end