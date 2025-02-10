@echo off
setlocal EnableDelayedExpansion

:: =================================
:: Variable Initialization
:: =================================
set "INSTALL_STATUS=0"
set "FOUND_PATH="
set "VERSION_FILE="
set "BACKUP_DIR="
set "TEMP_DIR=%TEMP%\LCPlusInstall"
set "LOG_DIR=%TEMP_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\debug.log"
set "EXTRACT_DIR=%TEMP_DIR%\extracted"
set "MOD_COUNT=0"
set "ESC="
set "GREEN="
set "YELLOW="
set "RED="
set "BLUE="
set "CYAN="
set "WHITE="
set "RESET="

:: Add version variables here
set "VERSION=1.1.0"
set "LAST_MODIFIED=2025-02-10"

:: ANSI color support variables
set "ANSI_SUPPORT=0"
set "COLOR_ENABLED=0"

:: Installation state variables
set "BEPINEX_INSTALLED=0"
set "INSTALL_CONFIRMED=0"

:: Mod-specific variables
set "MOD_NAME="
set "MOD_VERSION="
set "MOD_AUTHOR="
set "DOWNLOAD_URL="
set "ZIP_FILE="
set "MOD_EXTRACT_DIR="
set "INSTALL_DIR="
set "SOURCE_DIR="

:: Temporary working variables
set "TEMP_CFG="
set "CONFIRM="
set "RESTORE="
set "ERROR_MESSAGE="
set "ERROR_CODE="

:: Add to initialization section
set "CONFIRMATION_FILE=%TEMP_DIR%\install_confirmed.flag"
set "INSTALL_STATUS=0"

:: =================================
:: Mod List Definition
:: =================================

:: Mod list (now a single string)
:: Format: ModName,Author;ModName,Author;...
set "ModList="
set "ModList=!ModList!BepInExPack,BepInEx;"
set "ModList=!ModList!LethalConfig,AinaVT;"
set "ModList=!ModList!VertexLibrary,LethalCompanyModding;"
set "ModList=!ModList!GeneralImprovements,ShaosilGaming;"
set "ModList=!ModList!EnemySoundFixes,ButteryStancakes;"
set "ModList=!ModList!BarberFixes,ButteryStancakes;"
set "ModList=!ModList!JetpackFixes,ButteryStancakes;"
set "ModList=!ModList!MeleeFixes,ButteryStancakes;"
set "ModList=!ModList!WeedKillerFixes,ButteryStancakes;"
set "ModList=!ModList!CullFactory,fumiko;"
set "ModList=!ModList!HideChat,Monkeytype;"
set "ModList=!ModList!FixRPCLag,Bobbie;"
set "ModList=!ModList!MoonPriceDisplay,Gloveman23;"
set "ModList=!ModList!RankFix,Glitch;"
set "ModList=!ModList!CoilHeadStare,TwinDimensionalProductions;"
set "ModList=!ModList!NilsHUD,Nilaier;"
set "ModList=!ModList!AccurateStaminaDisplay,ButteryStancakes;"
set "ModList=!ModList!LethalRichPresence,mrov;"
set "ModList=!ModList!AlwaysHearActiveWalkies,Suskitech;"
set "ModList=!ModList!ShipLoot,tinyhoot;"
set "ModList=!ModList!CompatibilityChecker,Ryokune;"

:: Calculate mod count (more efficient method)
set "MOD_COUNT=0"
for %%a in ("%ModList:;=";"%") do set /a "MOD_COUNT+=1"

:: Check admin privileges using WHOAMI
:CheckElevation
WHOAMI /GROUPS | findstr /b /c:"Mandatory Label\High Mandatory Level" >nul 2>&1
if %errorlevel% equ 0 (
    goto :ContinueInitialization
) else (
    call :RequestElevation
    exit /b
)

:RequestElevation
if not exist "%TEMP_DIR%" (
    mkdir "%TEMP_DIR%" || (
        echo Failed to create temp directory: "%TEMP_DIR%"
        pause
        exit /b 1
    )
)
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" || (
        echo Failed to create log directory: "%LOG_DIR%"
        pause
        exit /b 1
    )
)
echo Requesting administrator privileges...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process '%~f0' -Verb RunAs}"
exit /b

:ContinueInitialization
:: Initialize log file after elevation
echo [%date% %time%] Lethal Company Plus installation started > "%LOG_FILE%"
echo [%date% %time%] Initializing installer... >> "%LOG_FILE%"

:: Log version information silently
call :Log "LCPlus Installer Version: v%VERSION%"
call :Log "Batch Script Last Modified: %LAST_MODIFIED%"

:: Initialize installation status and paths
set "INSTALL_STATUS=0"
set "TEMP_DIR=%TEMP%\LCPlusInstall"
set "LOG_DIR=%TEMP_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\debug.log"
set "EXTRACT_DIR=%TEMP_DIR%\extracted"
set "FOUND_PATH="
set "VERSION_FILE="

:: Create required directories WITH ERROR HANDLING
if not exist "%TEMP_DIR%" (
    mkdir "%TEMP_DIR%" || (
        call :HandleError "Failed to create temp directory"
        exit /b 1
    )
)
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" || (
        call :HandleError "Failed to create log directory"
        exit /b 1
    )
)
if not exist "%EXTRACT_DIR%" (
    mkdir "%EXTRACT_DIR%" || (
        call :HandleError "Failed to create extract directory"
        exit /b 1
    )
)

:: Enable ANSI support and set up colors
reg add "HKCU\Software\Microsoft\Command Processor" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
if !errorlevel! neq 0 (
    reg add "HKLM\Software\Microsoft\Command Processor" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
)

powershell -Command "$host.UI.RawUI.ForegroundColor = 'Green'" >nul 2>&1
if !errorlevel! equ 0 (
    for /F %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
    set "GREEN=!ESC![92m"
    set "YELLOW=!ESC![93m"
    set "RED=!ESC![91m"
    set "BLUE=!ESC![94m"
    set "CYAN=!ESC![96m"
    set "WHITE=!ESC![97m"
    set "RESET=!ESC![0m"
) else (
    call :Log "WARNING: ANSI colors not supported" "console"
    set "ESC="
    set "GREEN="
    set "YELLOW="
    set "RED="
    set "BLUE="
    set "CYAN="
    set "WHITE="
    set "RESET="
)

:: Configure UTF-8 encoding
powershell -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" >nul

:: Configure PowerShell execution policy
powershell Set-ExecutionPolicy Bypass -Scope Process >nul 2>&1
if !errorlevel! neq 0 (
    powershell Set-ExecutionPolicy RemoteSigned -Scope Process >nul 2>&1
)

::==================================
:: Corrected Main Installation Flow
::==================================
:START_INSTALLATION
call :InitializeEnvironment
if %errorlevel% neq 0 goto :ERROR

call :LocateGame
if %errorlevel% neq 0 goto :ERROR

:: Single confirmation point
call :ShowModListAndConfirm
if not exist "!CONFIRMATION_FILE!" (
    call :Log "Installation cancelled by user" "console"
    call :ColorEcho YELLOW "Installation cancelled"
    set "INSTALL_STATUS=3"
    goto :CLEANUP
)

:: Install all components sequentially
call :InstallBepInExPack || (
    set "INSTALL_STATUS=1"
    goto :ERROR
)

call :InstallAllMods || (
    set "INSTALL_STATUS=2"
    goto :ERROR
)

goto :CLEANUP

::==================================
:: Updated Mod Installation Function
::==================================
:InstallAllMods
setlocal EnableDelayedExpansion
call :ColorEcho BLUE "► Beginning mod installation..."
echo.
call :ColorEcho WHITE "Installing %MOD_COUNT% mods..."

for %%a in ("%ModList:;=";"%") do (
    for /f "tokens=1,2 delims=," %%b in ("%%~a") do (
        if /i not "%%b"=="BepInExPack" (
            call :InstallSingleMod "%%c" "%%b"
        )
    )
)
endlocal
exit /b 0

::==================================
:: Single Mod Installation Function
::==================================
:InstallSingleMod
setlocal EnableDelayedExpansion
set "MOD_AUTHOR=%~1"
set "MOD_NAME=%~2"

call :Log "Installing mod: !MOD_AUTHOR!/!MOD_NAME!" "console"
call :ColorEcho BLUE "► Installing !MOD_NAME!..."

:: Maintain Thunderstore's API structure: package/author/name/
set "MOD_API_URL=https://thunderstore.io/api/experimental/package/!MOD_AUTHOR!/!MOD_NAME!/"
call :Log "DEBUG: Calling API URL: !MOD_API_URL!"

:: Fetch mod info with improved error handling and JSON depth
powershell -Command "$ErrorActionPreference = 'Stop'; try { $ProgressPreference = 'SilentlyContinue'; $response = Invoke-RestMethod -Uri '!MOD_API_URL!' -Method Get; $jsonResponse = $response | ConvertTo-Json -Depth 10; $jsonResponse | Out-File '!TEMP_DIR!\!MOD_NAME!_response.json' -Encoding UTF8; Write-Output ('VERSION=' + $response.latest.version_number); Write-Output ('URL=' + $response.latest.download_url) } catch { Write-Error $_.Exception.Message; exit 1 }" > "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>"!LOG_DIR!\!MOD_NAME!_api_error.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to fetch mod info for !MOD_NAME!" 1 "!LOG_DIR!\!MOD_NAME!_api_error.log"
    endlocal
    exit /b 1
)

:: Parse version and URL using findstr
for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "VERSION=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "DOWNLOAD_URL=%%a"

:: Trim whitespace from parsed values
set "VERSION=!VERSION: =!"
set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

if not defined VERSION (
    call :Log "ERROR: Failed to parse version from API response" "console"
    call :ColorEcho RED "ERROR: Invalid API response for !MOD_NAME!"
    endlocal
    exit /b 1
)

if not defined DOWNLOAD_URL (
    call :Log "ERROR: Failed to parse download URL from API response" "console"
    call :ColorEcho RED "ERROR: Invalid API response for !MOD_NAME!"
    endlocal
    exit /b 1
)

:: Clean up temporary files
del "!TEMP_DIR!\!MOD_NAME!_response.json" 2>nul
del "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>nul

:: Setup paths with logging
set "ZIP_FILE=!TEMP_DIR!\!MOD_NAME!_v!VERSION!.zip"
set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"

:: Download mod files
call :DownloadMod "!DOWNLOAD_URL!" "!ZIP_FILE!" "!MOD_NAME!"
if !errorlevel! neq 0 (
    endlocal
    exit /b 1
)

:: Extract and install
call :ExtractAndInstallMod "!ZIP_FILE!" "!MOD_EXTRACT_DIR!" "!MOD_NAME!"
if !errorlevel! neq 0 (
    endlocal
    exit /b 1
)

:: Write version information (This MUST happen BEFORE endlocal)
call :WriteVersionInfo "!MOD_NAME!" "!VERSION!"
if !errorlevel! neq 0 (
    endlocal
    exit /b 1
)

call :ColorEcho GREEN "✓ Successfully installed !MOD_NAME! v!VERSION!"
endlocal
exit /b 0

::==================================
:: Updated ShowModListAndConfirm
:: =================================
:ShowModListAndConfirm
setlocal EnableDelayedExpansion
del "!CONFIRMATION_FILE!" 2>nul

:: Display mod list
call :ColorEcho CYAN "The following will be installed:"
echo.
call :ColorEcho WHITE "  - BepInExPack (Core Mod Loader) by BepInEx"

for %%a in ("%ModList:;=";"%") do (
    for /f "tokens=1,2 delims=," %%b in ("%%~a") do (
        if /i not "%%b"=="BepInExPack" (
            call :ColorEcho WHITE "  - %%b by %%c"
        )
    )
)

:: Get explicit confirmation
:CONFIRM_LOOP
echo.
call :ColorEcho YELLOW "Install %MOD_COUNT% mods? (Y/N)"
set /p "USER_INPUT= "
set "USER_INPUT=!USER_INPUT: =!"

if /i "!USER_INPUT!"=="Y" (
    echo CONFIRMED > "!CONFIRMATION_FILE!"
    endlocal
    exit /b 0
) else if /i "!USER_INPUT!"=="N" (
    endlocal
    exit /b 1
) else (
    call :ColorEcho RED "Invalid input. Please enter Y or N."
    goto :CONFIRM_LOOP
)

::==================================
:: Helper Functions (with documentation)
::==================================

:: Logging function
:: Purpose: Writes messages to log file and optionally to console
:: Parameters:
::   %1 - Message to log
::   %2 - "console" to also output to console
:: Globals Modified: LOG_FILE
:: Error Codes: Always returns 0
:Log
set "MESSAGE=%~1"
set "CONSOLE=%~2"
echo [%date% %time%] !MESSAGE! >> "!LOG_FILE!"
if "!CONSOLE!"=="console" echo !MESSAGE!
exit /b 0

:: Colored output function
:: Purpose: Outputs text with ANSI color codes if supported
:: Parameters:
::   %1 - Color name (GREEN, RED, etc.)
::   %2 - Message to display
:: Globals Modified: Uses color variables (GREEN, RED, etc.)
:: Error Codes: Always returns 0
:ColorEcho
set "COLOR=%~1"
set "MESSAGE=%~2"
if defined %COLOR% (
    echo !%COLOR%!!MESSAGE!!RESET!
) else (
    echo !MESSAGE!
)
exit /b 0

:: Environment initialization
:: Purpose: Verifies system requirements and prepares environment
:: Parameters: None
:: Globals Modified: Sets up TEMP_DIR, LOG_DIR, etc.
:: Error Codes:
::   0 - Success
::   1 - Missing requirements (PS version, disk space, etc.)
:InitializeEnvironment
setlocal EnableDelayedExpansion
call :ColorEcho BLUE "► Initializing environment..."
call :Log "Checking environment requirements..."

:: Configure UTF-8 code page
chcp 65001 >nul
call :Log "Set active code page to 65001 (UTF-8)"

:: Check PowerShell version
powershell -Command "$ErrorActionPreference = 'Stop'; try { if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'PowerShell 5.0+ required' } } catch { $_.Exception | Out-File '!LOG_DIR!\ps_version_check.log'; exit 1 }" >nul 2>&1
if !errorlevel! neq 0 (
    call :HandleError "PowerShell 5.0 or higher is required" 1 "!LOG_DIR!\ps_version_check.log"
    endlocal
    exit /b 1
)

:: Check internet connectivity
call :Log "Checking internet connectivity..."
powershell -Command "$ErrorActionPreference = 'Stop'; try { Test-NetConnection -ComputerName thunderstore.io -Port 443 } catch { $_.Exception | Out-File '!LOG_DIR!\connectivity_check.log'; exit 1 }" >nul 2>&1
if !errorlevel! neq 0 (
    call :HandleError "No internet connection or Thunderstore.io is unreachable" 1 "!LOG_DIR!\connectivity_check.log"
    endlocal
    exit /b 1
)

:: Check available disk space
call :Log "Checking available disk space..."
powershell -Command "$ErrorActionPreference = 'Stop'; try { $drive = (Get-Item '%TEMP%').PSDrive; if ($drive.Free -lt 1GB) { throw 'Insufficient disk space' } } catch { $_.Exception | Out-File '!LOG_DIR!\space_check.log'; exit 1 }" >nul 2>&1
if !errorlevel! neq 0 (
    call :HandleError "Insufficient disk space (1GB required)" 1 "!LOG_DIR!\space_check.log"
    endlocal
    exit /b 1
)

call :Log "Environment check completed successfully"
endlocal
exit /b 0

:: Game location finder
:: Purpose: Locates Lethal Company installation path
:: Parameters: None
:: Globals Modified:
::   Sets FOUND_PATH on success
::   Uses STEAM_PATH during search
:: Error Codes:
::   0 - Success
::   1 - Game not found
:LocateGame
setlocal EnableDelayedExpansion
call :Log "Starting game location detection..." "console"
call :ColorEcho BLUE "► Locating Lethal Company installation..."

:: Check registry locations with proper quoting
for %%A in (
    "HKCU\Software\Valve\Steam"
    "HKLM\Software\Valve\Steam"
    "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 1966720"
) do (
    call :Log "Checking registry: %%~A"
    reg query "%%~A" /v "InstallLocation" 2>nul | findstr /I /C:"InstallLocation" >nul && (
        for /f "tokens=2,*" %%B in ('reg query "%%~A" /v "InstallLocation" 2^>nul') do (
            set "STEAM_PATH=%%C"
            call :Log "Found Steam path: !STEAM_PATH!"
            if exist "!STEAM_PATH!\Lethal Company.exe" (
                set "FOUND_PATH=!STEAM_PATH!"
                goto :ValidateGamePath
            )
        )
    ) || (
        call :Log "Registry entry not found: %%~A"
    )
)

:: Search all Steam library folders
if defined STEAM_PATH (
    if exist "!STEAM_PATH!\steamapps\libraryfolders.vdf" (
        powershell -Command "$content = Get-Content '^!STEAM_PATH!\steamapps\libraryfolders.vdf'; $paths = $content | Select-String '^\s*\"path\"\s*\"([^\"]+)\"' | %%{ $_.Matches.Groups[1].Value }; $paths | %%{ if (Test-Path -LiteralPath \"$_\\steamapps\\common\\Lethal Company\") { \"$_\\steamapps\\common\\Lethal Company\" } }" > "!TEMP_DIR!\steam_libs.txt"
        
        for /f "usebackq delims=" %%i in ("!TEMP_DIR!\steam_libs.txt") do (
            if exist "%%i\Lethal Company.exe" (
                set "FOUND_PATH=%%i"
                goto :ValidateGamePath
            )
        )
        del "!TEMP_DIR!\steam_libs.txt" 2>nul
    )
)

:: Manual input with validation loop
:ManualInput
call :ColorEcho YELLOW "Could not auto-detect installation."
echo.
echo Enter your Lethal Company path (containing Lethal Company.exe):
set /p "FOUND_PATH=Path: "
if not defined FOUND_PATH goto :ManualInput

:ValidateGamePath
set "FOUND_PATH=!FOUND_PATH:"=!"
if "!FOUND_PATH:~-1!"=="\" set "FOUND_PATH=!FOUND_PATH:~0,-1!"
if not exist "!FOUND_PATH!\Lethal Company.exe" (
    call :Log "Invalid path: !FOUND_PATH!"
    echo Invalid path. Lethal Company.exe not found.
    goto :ManualInput
)
call :ColorEcho GREEN "✓ Lethal Company install located at: !FOUND_PATH!"
call :Log "Valid game path found: !FOUND_PATH!" "console"
endlocal & set "FOUND_PATH=%FOUND_PATH%"
exit /b 0

::==================================
:: More Helper Functions (continuing in required order)
::==================================

:: Backup creation
:: Purpose: Creates backup of existing mod installation
:: Parameters: None
:: Globals Modified:
::   Sets BACKUP_DIR
::   Uses FOUND_PATH
:: Error Codes:
::   0 - Success or no backup needed
::   1 - Backup failure
:CreateBackup
setlocal EnableDelayedExpansion
call :ColorEcho BLUE "► Creating backup..."

set "BACKUP_DIR=%TEMP_DIR%\backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "BACKUP_DIR=%BACKUP_DIR: =0%"

:: Check if BepInEx exists
if exist "!FOUND_PATH!\BepInEx" (
    mkdir "!BACKUP_DIR!" 2>nul || (
        call :HandleError "Failed to create backup directory" 4
        goto :CreateBackup_End
    )

    :: Create backup with logging
    xcopy "!FOUND_PATH!\BepInEx" "!BACKUP_DIR!\BepInEx\" /E /H /C /I /Y /Q >"!LOG_DIR!\backup.log" 2>&1
    if !errorlevel! neq 0 (
        call :HandleError "Failed to create backup" 1 "!LOG_DIR!\backup.log"
        goto :CreateBackup_End
    )

    :: Also backup doorstop files if they exist
    if exist "!FOUND_PATH!\winhttp.dll" (
        copy "!FOUND_PATH!\winhttp.dll" "!BACKUP_DIR!\" /Y >nul
    )
    if exist "!FOUND_PATH!\doorstop_config.ini" (
        copy "!FOUND_PATH!\doorstop_config.ini" "!BACKUP_DIR!\" /Y >nul
    )

    call :Log "Created backup at: !BACKUP_DIR!" "console"
    call :ColorEcho GREEN "✓ Backup created successfully"
) else (
    call :Log "No existing BepInEx installation found, skipping backup" "console"
    call :ColorEcho YELLOW "No existing installation found to backup"
)

:CreateBackup_End
endlocal & set "BACKUP_DIR=%BACKUP_DIR%"
exit /b 0

:: 6. Restore from backup
:RestoreBackup
setlocal EnableDelayedExpansion
call :ColorEcho BLUE "► Restoring backup..."

:: Verify backup exists
if not exist "!BACKUP_DIR!\BepInEx" (
    call :HandleError "Backup directory not found or invalid" 5
    goto :RestoreBackup_End
)

:: Remove current installation if it exists
if exist "!FOUND_PATH!\BepInEx" (
    rd /s /q "!FOUND_PATH!\BepInEx"
    if !errorlevel! neq 0 (
        call :HandleError "Failed to remove current installation"
        goto :RestoreBackup_End
    )
)

:: Restore BepInEx directory
xcopy "!BACKUP_DIR!\BepInEx" "!FOUND_PATH!\BepInEx\" /E /H /C /I /Y /Q >"!LOG_DIR!\restore.log" 2>&1
if !errorlevel! neq 0 (
    call :HandleError "Failed to restore BepInEx directory" 1 "!LOG_DIR!\restore.log"
    goto :RestoreBackup_End
)

:: Restore doorstop files if they exist in backup
if exist "!BACKUP_DIR!\winhttp.dll" (
    copy "!BACKUP_DIR!\winhttp.dll" "!FOUND_PATH!\" /Y >nul
)
if exist "!BACKUP_DIR!\doorstop_config.ini" (
    copy "!BACKUP_DIR!\doorstop_config.ini" "!FOUND_PATH!\" /Y >nul
)

call :Log "Successfully restored from backup" "console"
call :ColorEcho GREEN "✓ Backup restored successfully"
:RestoreBackup_End
endlocal
exit /b 0

:: 7. Write version information
:WriteVersionInfo
set "MOD_NAME=%~1"
set "MOD_VERSION=%~2"
set "TEMP_FILE=%TEMP%\version_temp.txt"

set "VERSION_FILE=!FOUND_PATH!\BepInEx\config\LCPlus_Versions.txt"

:: Create config directory if it doesn't exist
if not exist "!FOUND_PATH!\BepInEx\config" (
    mkdir "!FOUND_PATH!\BepInEx\config" 2>nul
    if !errorlevel! neq 0 (
        call :HandleError "Failed to create config directory for mod: !MOD_NAME!" 6
        exit /b
    )
)

:: Create or update version file
if not exist "!VERSION_FILE!" (
    echo !MOD_NAME!=!MOD_VERSION!> "!VERSION_FILE!"
    if !errorlevel! neq 0 (
        call :HandleError "Failed to create version file"
        exit /b 1
    )
    exit /b 0
)

:: Create temporary file for version updates
if exist "!TEMP_FILE!" del /f /q "!TEMP_FILE!"
type nul > "!TEMP_FILE!" 2>nul
if !errorlevel! neq 0 (
    call :HandleError "Failed to create temporary file"
    exit /b 1
)

set "FOUND=0"
for /f "usebackq tokens=1,* delims==" %%a in ("!VERSION_FILE!") do (
    if "%%a"=="!MOD_NAME!" (
        echo !MOD_NAME!=!MOD_VERSION!>> "!TEMP_FILE!"
        set "FOUND=1"
    ) else (
        echo %%a=%%b>> "!TEMP_FILE!"
    )
)

if !FOUND!==0 (
    echo !MOD_NAME!=!MOD_VERSION!>> "!TEMP_FILE!"
)

:: Only move if both files exist
if exist "!TEMP_FILE!" (
    move /y "!TEMP_FILE!" "!VERSION_FILE!" >nul
    if !errorlevel! neq 0 (
        call :HandleError "Failed to update version file"
        if exist "!TEMP_FILE!" del /f /q "!TEMP_FILE!"
        exit /b 1
    )
)

call :Log "Updated version information for !MOD_NAME! to v!MOD_VERSION!"
exit /b 0

:: Mod downloader
:: Purpose: Downloads mod files from Thunderstore
:: Parameters:
::   %1 - Download URL
::   %2 - Output file path
::   %3 - Mod name (for logging)
:: Globals Modified:
::   Creates ZIP_FILE
::   Updates LOG_FILE
:: Error Codes:
::   0 - Success
::   1 - Download failed
:DownloadMod
setlocal EnableDelayedExpansion
set "URL=%~1"
set "OUTPUT=%~2"
set "MOD_NAME=%~3"

call :Log "Downloading !MOD_NAME! from !URL!" "console"
call :ColorEcho WHITE "⚙ Downloading !MOD_NAME!..."

powershell -Command "$ErrorActionPreference = 'Stop'; try { $ProgressPreference = 'SilentlyContinue'; $webClient = New-Object System.Net.WebClient; $webClient.Headers.Add('User-Agent', 'Mozilla/5.0'); $webClient.DownloadFile('!URL!', '!OUTPUT!') } catch { Write-Error $_.Exception.Message; exit 1 }" 2>"!LOG_DIR!\!MOD_NAME!_download.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to download !MOD_NAME!" 1 "!LOG_DIR!\!MOD_NAME!_download.log"
    endlocal
    exit /b 1
)

if not exist "!OUTPUT!" (
    call :HandleError "Download file not found for !MOD_NAME!"
    endlocal
    exit /b 1
)

for %%A in ("!OUTPUT!") do (
    if %%~zA LEQ 0 (
        call :Log "ERROR: Downloaded file is empty for !MOD_NAME!" "console"
        call :ColorEcho RED "ERROR: Download verification failed for !MOD_NAME!"
        del "!OUTPUT!" 2>nul
        endlocal
        exit /b 1
    )
)

call :Log "Successfully downloaded !MOD_NAME!"
endlocal
exit /b 0

:: 9. Extract and install mod files
:ExtractAndInstallMod
setlocal EnableDelayedExpansion
set "ZIP_FILE=%~1"
set "EXTRACT_DIR=%~2"
set "MOD_NAME=%~3"
set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"
set "INSTALL_DIR=!FOUND_PATH!\BepInEx\plugins\!MOD_NAME!"
set "INSTALL_LOG=!LOG_DIR!\!MOD_NAME!_install.log"

call :Log "Extracting !MOD_NAME! from !ZIP_FILE! to !EXTRACT_DIR!" "console"
call :ColorEcho WHITE "⚙ Extracting files..."

if exist "!MOD_EXTRACT_DIR!" (
    rd /s /q "!MOD_EXTRACT_DIR!" || (
        call :HandleError "Failed to remove existing extraction directory"
        endlocal
        exit /b 1
    )
)

powershell -Command "$ErrorActionPreference = 'Stop'; try { Expand-Archive -Path '!ZIP_FILE!' -DestinationPath '!MOD_EXTRACT_DIR!' -Force } catch { Write-Error $_.Exception.Message; exit 1 }" 2>"!LOG_DIR!\!MOD_NAME!_extract.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to extract !MOD_NAME!" 1 "!LOG_DIR!\!MOD_NAME!_extract.log"
    endlocal
    exit /b 1
)

mkdir "!INSTALL_DIR!" 2>nul
if not exist "!INSTALL_DIR!" (
    call :HandleError "Failed to create install directory: !INSTALL_DIR!"
    endlocal
    exit /b 1
)

:: Check for plugins folder and handle file copying accordingly
call :Log "Checking for plugins folder in !MOD_EXTRACT_DIR!" "console"
if exist "!MOD_EXTRACT_DIR!\plugins" (
    call :Log "Found plugins folder - performing two-step copy" "console"
    
    :: Step 1: Copy files from within plugins folder
    powershell -Command "$ErrorActionPreference = 'Stop'; try { $source = '!MOD_EXTRACT_DIR!\plugins'; Get-ChildItem -Path $source -Recurse -File | Copy-Item -Destination '!INSTALL_DIR!' -Force } catch { Write-Error $_.Exception.Message; exit 1 }" >> "!INSTALL_LOG!" 2>&1
    
    if !errorlevel! neq 0 (
        call :Log "ERROR: Failed to copy files from plugins folder - Check !INSTALL_LOG!" "console"
        call :ColorEcho RED "ERROR: Installation failed for !MOD_NAME!"
        type "!INSTALL_LOG!" >> "!LOG_FILE!"
        endlocal
        exit /b 1
    )
    
    :: Step 2: Copy files from root (excluding plugins folder)
    powershell -Command "$ErrorActionPreference = 'Stop'; try { Get-ChildItem -Path '!MOD_EXTRACT_DIR!' -Exclude 'plugins' -Recurse -File | Copy-Item -Destination '!INSTALL_DIR!' -Force } catch { Write-Error $_.Exception.Message; exit 1 }" >> "!INSTALL_LOG!" 2>&1
) else (
    call :Log "No plugins folder found - copying all files from root" "console"
    
    :: Copy all files from root
    powershell -Command "$ErrorActionPreference = 'Stop'; try { Get-ChildItem -Path '!MOD_EXTRACT_DIR!' -Recurse -File | Copy-Item -Destination '!INSTALL_DIR!' -Force } catch { Write-Error $_.Exception.Message; exit 1 }" >> "!INSTALL_LOG!" 2>&1
)

if !errorlevel! neq 0 (
    call :HandleError "Failed to copy mod files - Check !INSTALL_LOG!" 1 "!INSTALL_LOG!"
    endlocal
    exit /b 1
)

dir /b "!INSTALL_DIR!\*.dll" >nul 2>&1
if !errorlevel! neq 0 (
    call :HandleError "No DLL files found in installed files for !MOD_NAME!"
    endlocal
    exit /b 1
)

exit /b 0

::==================================
:: BepInEx Configuration Functions
::==================================

:: 10. Configure BepInEx installation
:ConfigureBepInEx
setlocal EnableDelayedExpansion
call :Log "Configuring BepInEx..." "console"
call :ColorEcho BLUE "► Configuring BepInEx..."

if not exist "!FOUND_PATH!\BepInEx\config" (
    mkdir "!FOUND_PATH!\BepInEx\config" 2>nul
    if !errorlevel! neq 0 (
        call :HandleError "Failed to create BepInEx config directory" 6
        endlocal
        exit /b 6
    )
)

set "BEPINEX_CFG=!FOUND_PATH!\BepInEx\config\BepInEx.cfg"

:: Create or update configuration
if not exist "!BEPINEX_CFG!" (
    call :CreateDefaultBepInExConfig
    if !errorlevel! neq 0 (
        endlocal
        exit /b 1
    )
) else (
    call :UpdateBepInExConfig
    if !errorlevel! neq 0 (
        endlocal
        exit /b 1
    )
)

call :ColorEcho GREEN "✓ BepInEx configuration complete"
endlocal
exit /b 0

:: 11. Create default BepInEx configuration
:CreateDefaultBepInExConfig
setlocal EnableDelayedExpansion
call :Log "Creating default BepInEx configuration..."

(
    echo [Logging.Console]
    echo Enabled = true
    echo.
    echo [Logging.Disk]
    echo WriteUnityLog = false
    echo.
    echo [Paths]
    echo BepInExRootPath = BepInEx
    echo.
    echo [Preloader.Entrypoint]
    echo Assembly = BepInEx.Preloader.dll
    echo.
    echo [Loading]
    echo LoadPlugins = true
) > "!BEPINEX_CFG!" 2>"!LOG_DIR!\bepinex_config_create.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to create BepInEx configuration" 1 "!LOG_DIR!\bepinex_config_create.log"
    endlocal
    exit /b 1
)

call :Log "Created default BepInEx configuration"
endlocal
exit /b 0

:: 12. Update existing BepInEx configuration
:UpdateBepInExConfig
setlocal EnableDelayedExpansion
call :Log "Updating BepInEx configuration..."

set "TEMP_CFG=!TEMP_DIR!\BepInEx.cfg.tmp"
set "IN_LOGGING_CONSOLE=0"
set "IN_LOADING=0"
set "CONSOLE_FOUND=0"
set "LOADING_FOUND=0"

(for /f "usebackq delims=" %%a in ("!BEPINEX_CFG!") do (
    set "LINE=%%a"
    if "!LINE!"=="[Logging.Console]" (
        set "IN_LOGGING_CONSOLE=1"
        set "CONSOLE_FOUND=1"
        echo !LINE!
    ) else if "!LINE!"=="[Loading]" (
        set "IN_LOADING=1"
        set "LOADING_FOUND=1"
        echo !LINE!
    ) else if "!LINE!"=="" (
        set "IN_LOGGING_CONSOLE=0"
        set "IN_LOADING=0"
        echo.
    ) else (
        if "!IN_LOGGING_CONSOLE!"=="1" (
            if "!LINE:~0,8!"=="Enabled " (
                echo Enabled = true
            ) else (
                echo !LINE!
            )
        ) else if "!IN_LOADING!"=="1" (
            if "!LINE:~0,12!"=="LoadPlugins " (
                echo LoadPlugins = true
            ) else (
                echo !LINE!
            )
        ) else (
            echo !LINE!
        )
    )
)

if !CONSOLE_FOUND!==0 (
    echo.
    echo [Logging.Console]
    echo Enabled = true
)

if !LOADING_FOUND!==0 (
    echo.
    echo [Loading]
    echo LoadPlugins = true
)) > "!TEMP_CFG!" 2>"!LOG_DIR!\bepinex_config_update.log"

move /y "!TEMP_CFG!" "!BEPINEX_CFG!" >nul
if !errorlevel! neq 0 (
    call :HandleError "Failed to update BepInEx configuration" 1 "!LOG_DIR!\bepinex_config_update.log"
    endlocal
    exit /b 1
)

call :Log "Updated BepInEx configuration"
endlocal
exit /b 0

::==================================
:: Installation Functions
::==================================

:: 13. Install a single mod
:InstallMod
setlocal EnableDelayedExpansion
set "MOD_AUTHOR=%~1"
set "MOD_NAME=%~2"

call :Log "Installing mod: !MOD_AUTHOR!/!MOD_NAME!" "console"
call :ColorEcho BLUE "► Installing !MOD_NAME!..."

:: Corrected API URL with proper name/author order
set "MOD_API_URL=https://thunderstore.io/api/experimental/package/!MOD_AUTHOR!/!MOD_NAME!/"
call :Log "DEBUG: Calling API URL: !MOD_API_URL!"

:: Fetch mod info with improved error handling and JSON depth
powershell -Command "$ErrorActionPreference = 'Stop'; try { $ProgressPreference = 'SilentlyContinue'; $response = Invoke-RestMethod -Uri '!MOD_API_URL!' -Method Get; $jsonResponse = $response | ConvertTo-Json -Depth 10; $jsonResponse | Out-File '!TEMP_DIR!\!MOD_NAME!_response.json' -Encoding UTF8; Write-Output ('VERSION=' + $response.latest.version_number); Write-Output ('URL=' + $response.latest.download_url) } catch { Write-Error $_.Exception.Message; exit 1 }" > "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>"!LOG_DIR!\!MOD_NAME!_api_error.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to fetch mod info for !MOD_NAME!" 1 "!LOG_DIR!\!MOD_NAME!_api_error.log"
    endlocal
    exit /b 1
)

:: Parse version and URL using findstr
for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "VERSION=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "DOWNLOAD_URL=%%a"

:: Trim whitespace from parsed values
set "VERSION=!VERSION: =!"
set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

if not defined VERSION (
    call :Log "ERROR: Failed to parse version from API response" "console"
    call :ColorEcho RED "ERROR: Invalid API response for !MOD_NAME!"
    endlocal
    exit /b 1
)

if not defined DOWNLOAD_URL (
    call :Log "ERROR: Failed to parse download URL from API response" "console"
    call :ColorEcho RED "ERROR: Invalid API response for !MOD_NAME!"
    endlocal
    exit /b 1
)

:: Clean up temporary files
del "!TEMP_DIR!\!MOD_NAME!_response.json" 2>nul
del "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>nul

:: Setup paths with logging
set "ZIP_FILE=!TEMP_DIR!\!MOD_NAME!_v!VERSION!.zip"
set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"

:: Download mod files
call :DownloadMod "!DOWNLOAD_URL!" "!ZIP_FILE!" "!MOD_NAME!"
if !errorlevel! neq 0 (
    endlocal
    exit /b 1
)

:: Extract and install
call :ExtractAndInstallMod "!ZIP_FILE!" "!MOD_EXTRACT_DIR!" "!MOD_NAME!"
if !errorlevel! neq 0 (
    endlocal
    exit /b 1
)

:: Write version information (This MUST happen BEFORE endlocal)
call :WriteVersionInfo "!MOD_NAME!" "!VERSION!"
if !errorlevel! neq 0 (
    endlocal
    exit /b 1
)

call :ColorEcho GREEN "✓ Successfully installed !MOD_NAME! v!VERSION!"
endlocal
exit /b 0

:: 14. Install BepInExPack
:InstallBepInExPack
setlocal EnableDelayedExpansion
call :Log "Starting BepInExPack installation..." "console"
call :ColorEcho BLUE "► Installing BepInExPack..."

:: Construct API URL
set "MOD_API_URL=https://thunderstore.io/api/experimental/package/BepInEx/BepInExPack/"
call :Log "DEBUG: Calling API URL: !MOD_API_URL!"

:: Fetch mod info
powershell -Command "$ErrorActionPreference = 'Stop'; try { $ProgressPreference = 'SilentlyContinue'; $response = Invoke-RestMethod -Uri '!MOD_API_URL!' -Method Get; $jsonResponse = $response | ConvertTo-Json -Depth 10; $jsonResponse | Out-File '!TEMP_DIR!\BepInExPack_response.json' -Encoding UTF8; Write-Output ('VERSION=' + $response.latest.version_number); Write-Output ('URL=' + $response.latest.download_url) } catch { Write-Error $_.Exception.Message; exit 1 }" > "!TEMP_DIR!\BepInExPack_api.txt" 2>"!LOG_DIR!\BepInExPack_api_error.log"

if !errorlevel! neq 0 (
    call :Log "ERROR: Failed to fetch BepInExPack info - Check !LOG_DIR!\BepInExPack_api_error.log" "console"
    call :ColorEcho RED "ERROR: Failed to fetch BepInExPack data"
    type "!LOG_DIR!\BepInExPack_api_error.log" >> "!LOG_FILE!"
    endlocal
    exit /b 1
)

:: Parse version and URL
for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!TEMP_DIR!\BepInExPack_api.txt"') do set "VERSION=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!TEMP_DIR!\BepInExPack_api.txt"') do set "DOWNLOAD_URL=%%a"

:: Trim whitespace
set "VERSION=!VERSION: =!"
set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

:: Setup paths
set "ZIP_FILE=!TEMP_DIR!\BepInExPack_v!VERSION!.zip"
set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\BepInExPack"

:: Download BepInExPack
call :DownloadMod "!DOWNLOAD_URL!" "!ZIP_FILE!" "BepInExPack"
if !errorlevel! neq 0 (
    endlocal
    exit /b 1
)

:: Extract BepInExPack
call :Log "Extracting BepInExPack..." "console"
if exist "!MOD_EXTRACT_DIR!" rd /s /q "!MOD_EXTRACT_DIR!"
mkdir "!MOD_EXTRACT_DIR!" 2>nul

powershell -Command "$ErrorActionPreference = 'Stop'; try { Expand-Archive -Path '!ZIP_FILE!' -DestinationPath '!MOD_EXTRACT_DIR!' -Force } catch { Write-Error $_.Exception.Message; exit 1 }" 2>"!LOG_DIR!\BepInExPack_extract.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to extract BepInExPack" 1 "!LOG_DIR!\BepInExPack_extract.log"
    endlocal
    exit /b 1
)

:: Set the correct source directory
set "SOURCE_DIR=!MOD_EXTRACT_DIR!\BepInExPack"
if not exist "!SOURCE_DIR!\BepInEx\*" (
    call :Log "ERROR: BepInEx folder not found in extracted BepInExPack contents" "console"
    call :ColorEcho RED "ERROR: Invalid BepInExPack structure"
    endlocal
    exit /b 1
)

:: Copy the entire BepInEx folder to the game's root
call :Log "Copying BepInEx files to: !FOUND_PATH!" "console"
xcopy "!SOURCE_DIR!\BepInEx" "!FOUND_PATH!\BepInEx" /E /H /C /I /Y /Q >>"!LOG_DIR!\BepInExPack_install.log" 2>&1
if !errorlevel! neq 0 (
    call :Log "ERROR: Failed to copy BepInEx files" "console"
    call :ColorEcho RED "ERROR: Installation failed"
    type "!LOG_DIR!\BepInExPack_install.log" >> "!LOG_FILE!"
    endlocal
    exit /b 1
)

:: Create plugins folder if it doesn't exist
if not exist "!FOUND_PATH!\BepInEx\plugins" (
    mkdir "!FOUND_PATH!\BepInEx\plugins"
    call :Log "Created missing BepInEx\plugins folder." "console"
)

:: Copy additional root files (winhttp.dll, doorstop_config.ini, changelog.txt)
for %%a in ("winhttp.dll", "doorstop_config.ini", "changelog.txt") do (
    set "SOURCE_FILE=!SOURCE_DIR!\%%a"
    if exist "!SOURCE_FILE!" (
        call :Log "Copying !SOURCE_FILE! to game root"
        copy "!SOURCE_FILE!" "!FOUND_PATH!\" /Y >>"!LOG_DIR!\BepInExPack_install.log" 2>&1
        if !errorlevel! neq 0 (
            call :Log "ERROR: Failed to copy file: %%a" "console"
            call :ColorEcho RED "ERROR: Failed to copy file: %%a"
            type "!LOG_DIR!\BepInExPack_install.log" >> "!LOG_FILE!"
            endlocal
            exit /b 1
        )
    )
)

:: Configure BepInEx (after successful copy)
call :ConfigureBepInEx
if !errorlevel! neq 0 (
    endlocal
    exit /b 1
)

call :Log "BepInExPack installation completed successfully" "console"
call :ColorEcho GREEN "✓ BepInExPack installed successfully"
endlocal
exit /b 0

::==================================
:: Main Installation Flow
::==================================

:: 15. List and Install Mods (after all helper functions)
:InstallComponents
setlocal EnableDelayedExpansion
call :Log "Starting mod installation process..." "console"
call :ColorEcho CYAN "The following mods will be installed:"
echo.

:: Preview all mods first
for %%a in ("%ModList:;=";"%") do (
    for /f "tokens=1,2 delims=," %%b in ("%%~a") do (
        if /i not "%%b"=="BepInExPack" (
            call :ColorEcho WHITE "  - %%b by %%c"
        )
    )
)
echo.

:: User confirmation before proceeding
call :Log "All mods listed. Awaiting user confirmation..." "console"
call :ColorEcho YELLOW "Ready to begin installation. This may take a few minutes."
set /p "CONTINUE=Press Enter to start installation or Ctrl+C to cancel..."
echo.

:: Create backup before proceeding
call :CreateBackup
if !errorlevel! neq 0 (
    endlocal
    exit /b !errorlevel!
)

:: Install each mod
for %%a in ("%ModList:;=";"%") do (
    for /f "tokens=1,2 delims=," %%b in ("%%~a") do (
        if /i not "%%b"=="BepInExPack" (
            call :Log "Processing mod: %%b by %%c" "console"
            call :InstallMod "%%c" "%%b"
            if !errorlevel! neq 0 (
                call :HandleError "Failed to install mod: %%b"
                endlocal
                exit /b 1
            )
        )
    )
)

call :Log "Installation completed successfully" "console"
call :ColorEcho GREEN "✓ Installation completed successfully!"
endlocal
exit /b 0

::==================================
:: Error Handling and Cleanup
::==================================

:: 17. Error handling function
:ERROR
setlocal EnableDelayedExpansion
if "!INSTALL_STATUS!" equ "3" goto :CLEANUP

echo.
call :ColorEcho RED "X Installation failed!"
echo.
call :ColorEcho YELLOW "Troubleshooting steps:"
echo • Check the logs at: !LOG_DIR!
echo • Ensure you have a stable internet connection
echo • Try running the script as administrator
echo • Make sure the game is not running
echo • Verify your game files through Steam
echo.
call :ColorEcho YELLOW "If the problem persists, please report this issue"
call :ColorEcho YELLOW "by creating a GitHub issue with the log files."
endlocal
goto :CLEANUP

:: 18. Cleanup function
:CLEANUP
setlocal EnableDelayedExpansion
echo.

:: Remove temporary directories
rd /s /q "!EXTRACT_DIR!" 2>nul

:: Clean up zip files
del /f /q "!TEMP_DIR!\*.zip" 2>nul

:: Remove API response files
del /f /q "!TEMP_DIR!\*_api.txt" 2>nul
del /f /q "!TEMP_DIR!\*_response.json" 2>nul

:: Remove confirmation file
if exist "!CONFIRMATION_FILE!" (
    del "!CONFIRMATION_FILE!" && (
        call :Log "Cleaned up confirmation file"
    ) || (
        call :Log "WARNING: Failed to delete confirmation file" "console"
    )
)

endlocal

echo.
call :ColorEcho CYAN "Thanks for using Lethal Company Plus!"
call :ColorEcho CYAN "Press any key to exit..."
pause >nul

:: Error handler
:: Purpose: Centralized error processing and reporting
:: Parameters:
::   %1 - Error message
::   %2 - Optional error code (default 1)
::   %3 - Optional log file path
:: Globals Modified:
::   INSTALL_STATUS - Set to error code
::   LOG_FILE - Appends error details
:: Error Codes:
::   Always exits the script with the specified error code
:HandleError
setlocal EnableDelayedExpansion
set "ERROR_MESSAGE=%~1"
set "ERROR_CODE=%~2"
set "ERROR_LOG=%~3"

:: Default to error code 1 if not specified
if not defined ERROR_CODE set "ERROR_CODE=1"

:: Log error with timestamp
call :Log "ERROR [!ERROR_CODE!]: !ERROR_MESSAGE!" "console"
call :ColorEcho RED "X ERROR [!ERROR_CODE!]: !ERROR_MESSAGE!"

:: Append log file contents if provided
if defined ERROR_LOG (
    if exist "!ERROR_LOG!" (
        call :Log "Additional error details from !ERROR_LOG!:" "console"
        type "!ERROR_LOG!" >> "!LOG_FILE!"
    )
)

:: Set global error state and exit
endlocal & (
    set "INSTALL_STATUS=%ERROR_CODE%"
    exit /b %ERROR_CODE%
)