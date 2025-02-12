@echo off
setlocal EnableDelayedExpansion

:: =================================
:: Global Configuration
:: =================================
:: Core installation state tracking
set "INSTALL_STATUS=0"
set "FOUND_PATH="
set "VERSION_FILE="
set "BACKUP_DIR="

:: Temporary workspace configuration
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
set "VERSION=1.3.0"
set "LAST_MODIFIED=2025-02-12"

:: Updated error code descriptions with clearer categories
set "ERROR_CODE_1=General/unexpected error"
set "ERROR_CODE_2=Network communication failure"
set "ERROR_CODE_3=File/directory not found"
set "ERROR_CODE_4=Insufficient disk space"
set "ERROR_CODE_5=Backup/restore operation failure"
set "ERROR_CODE_6=BepInEx configuration error"
set "ERROR_CODE_7=Registry access failure"
set "ERROR_CODE_8=File operation failure (copy/delete)"
set "ERROR_CODE_9=Archive extraction failure"
set "ERROR_CODE_10=Invalid API response"
set "ERROR_CODE_11=User input validation failed"
set "ERROR_CODE_12=Permission denied"
set "ERROR_CODE_13=Invalid game installation path"
set "ERROR_CODE_14=Mod installation failure"

:: Mod-specific variables
set "MOD_AUTHOR="
set "DOWNLOAD_URL="
set "ZIP_FILE="
set "MOD_EXTRACT_DIR="
set "INSTALL_DIR="
set "SOURCE_DIR="

:: Temporary working variables
set "TEMP_CFG="
set "CONFIRM="

:: Add to initialization section
set "CONFIRMATION_FILE=%TEMP_DIR%\install_confirmed.flag"

:: =================================
:: USER CONFIRMATION DIALOG
:: =================================
:: ======================================================================
:: FUNCTION: CHECK_AND_REQUEST_ELEVATION
:: PURPOSE: Ensure script runs with admin privileges
:: ======================================================================
:CHECK_AND_REQUEST_ELEVATION
:: Verify current privilege level
WHOAMI /GROUPS | findstr /b /c:"Mandatory Label\High Mandatory Level" >nul 2>&1
if %errorlevel% equ 0 (
    goto :CONTINUE_INITIALIZATION
)

:: Create temp directories before elevation
call :CREATE_DIRECTORY "%TEMP_DIR%" || (
    call :HandleError "Temp directory creation failed: %TEMP_DIR%" 3
    goto :ERROR
)
call :CREATE_DIRECTORY "%LOG_DIR%" || (
    call :HandleError "Log directory creation failed: %LOG_DIR%" 3
    goto :ERROR
)

:: Request elevation using PowerShell
echo Requesting administrator privileges...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "& {Start-Process '%~f0' -Verb RunAs -ErrorAction Stop; exit $LASTEXITCODE}"
if %errorlevel% neq 0 (
    call :HandleError "Elevation request failed" 12
)
goto :ERROR

:: ======================================================================
:: FUNCTION: CONTINUE_INITIALIZATION
:: PURPOSE: Post-elevation environment setup
:: CRITICAL OPERATIONS:
::   - Creates required directories
::   - Initializes logging system
::   - Configures console environment
:: ======================================================================
:CONTINUE_INITIALIZATION
call :CREATE_DIRECTORY "%TEMP_DIR%" || exit /b 3
call :CREATE_DIRECTORY "%LOG_DIR%" || exit /b 3
call :CREATE_DIRECTORY "%EXTRACT_DIR%" || exit /b 3

:: Initialize log file AFTER directory creation
call :InitializeLogging

:: Initialize installation status and paths
set "INSTALL_STATUS=0"
set "TEMP_DIR=%TEMP%\LCPlusInstall"
set "LOG_DIR=%TEMP_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\debug.log"
set "EXTRACT_DIR=%TEMP_DIR%\extracted"
set "FOUND_PATH="
set "VERSION_FILE="

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
:: MAIN INSTALLATION FLOW
::==================================
:START_INSTALLATION
call :InitializeEnvironment
if %errorlevel% neq 0 call :HandleError "Environment initialization failed" 1

call :LocateGame
if %errorlevel% neq 0 call :HandleError "Game location failed" 2

call :DownloadModlist
if %errorlevel% neq 0 (
    call :HandleError "Failed to download/parse modlist.ini" 1
    goto :CLEANUP
)

:: *** NEW: Recalculate MOD_COUNT ***
set "MOD_COUNT=0"
for %%a in ("%MOD_LIST:;=";"%") do set /a "MOD_COUNT += 1"

:: *** NEW: Update User Confirmation (if desired) ***
:: At this point, MOD_LIST is updated.  If you want the user to see
:: the *correct* mod list from modlist.ini, you would modify the
:: SHOW_MOD_LIST_AND_CONFIRM function here.

call :SHOW_MOD_LIST_AND_CONFIRM
if errorlevel 1 (
    call :Log "Installation cancelled by user" "console"
    call :ColorEcho YELLOW "Installation cancelled"
    set "INSTALL_STATUS=3"
    goto :CLEANUP
)

call :INSTALL_BEPINEX_PACK
if %errorlevel% neq 0 call :HandleError "BepInEx installation failed" 3

call :INSTALL_ALL_MODS
if %errorlevel% neq 0 call :HandleError "Mod installation failed" 4

goto :CLEANUP

::==================================
:: MOD INSTALLATION FUNCTIONS
::==================================
:: ======================================================================
:: FUNCTION: INSTALL_ALL_MODS
:: PURPOSE: Installs all mods from MOD_LIST excluding BepInExPack
:: PROCESSING:
::   - Skips BepInExPack entry
::   - Processes mods in MOD_LIST order
:: ======================================================================
:INSTALL_ALL_MODS
setlocal EnableDelayedExpansion
call :ColorEcho BLUE "► Beginning mod installation..."
echo.
call :ColorEcho WHITE "Installing %MOD_COUNT% mods..."

:: Process each mod in the configured list
for %%a in ("%MOD_LIST:;=";"%") do (
    for /f "tokens=1,2 delims=," %%b in ("%%~a") do (
        :: Skip core loader to prevent duplicate installation
        if /i not "%%b"=="BepInExPack" (
            call :INSTALL_SINGLE_MOD "%%c" "%%b"
            if !errorlevel! neq 0 call :HandleError "Failed to install mod: %%b"
        )
    )
)
endlocal
exit /b 0

:: ======================================================================
:: FUNCTION: INSTALL_SINGLE_MOD
:: PURPOSE: Handle full installation lifecycle for individual mod
:: ======================================================================
:INSTALL_SINGLE_MOD
setlocal EnableDelayedExpansion
set "MOD_AUTHOR=%~1"
set "MOD_NAME=%~2"

:: Retrieve mod metadata from Thunderstore API
set "THUNDERSTORE_API_ENDPOINT=https://thunderstore.io/api/experimental/package/!MOD_AUTHOR!/!MOD_NAME!/"
powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "$ProgressPreference = 'SilentlyContinue';" ^
        "$response = Invoke-RestMethod -Uri '!THUNDERSTORE_API_ENDPOINT!'" ^
            " -Method Get;" ^
        "$jsonResponse = $response | ConvertTo-Json -Depth 10;" ^
        "$jsonResponse | Out-File '!TEMP_DIR!\!MOD_NAME!_response.json'" ^
            " -Encoding UTF8;" ^
        "Write-Output ('VERSION=' + $response.latest.version_number);" ^
        "Write-Output ('URL=' + $response.latest.download_url)" ^
    "} catch {" ^
        "Write-Error $_.Exception.Message;" ^
        "exit 1" ^
    "}" > "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>"!LOG_DIR!\!MOD_NAME!_api_error.log"

:: Validate API response data
if !errorlevel! neq 0 (
    call :HandleError "Failed to fetch mod info for !MOD_NAME!" 2 "!LOG_DIR!\!MOD_NAME!_api_error.log"
    endlocal
    exit /b 2
)

:: Parse version and URL using findstr
for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "MOD_VERSION=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "DOWNLOAD_URL=%%a"

:: Trim whitespace from parsed values
set "MOD_VERSION=!MOD_VERSION: =!"
set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

if not defined MOD_VERSION (
    call :Log "ERROR: Failed to parse version from API response"
    call :ColorEcho RED "ERROR: Invalid API response for !MOD_NAME!"
    endlocal
    exit /b 1
)

if not defined DOWNLOAD_URL (
    call :Log "ERROR: Failed to parse download URL from API response"
    call :ColorEcho RED "ERROR: Invalid API response for !MOD_NAME!"
    endlocal
    exit /b 1
)

:: Clean up temporary files
del "!TEMP_DIR!\!MOD_NAME!_response.json" 2>nul
del "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>nul

:: Setup paths with logging
set "ZIP_FILE=!TEMP_DIR!\!MOD_NAME!_v!MOD_VERSION!.zip"
set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"

:: Download mod files
call :DownloadMod "!DOWNLOAD_URL!" "!ZIP_FILE!" "!MOD_NAME!"
if !errorlevel! neq 0 call :HandleError "Download failed for !MOD_NAME!" 2 "!LOG_DIR!\!MOD_NAME!_download.log"

:: Extract and install
call :ExtractAndInstallMod "!ZIP_FILE!" "!MOD_EXTRACT_DIR!" "!MOD_NAME!"
if !errorlevel! neq 0 call :HandleError "Failed to extract !MOD_NAME! (!ZIP_FILE!)" 9 "!LOG_DIR!\!MOD_NAME!_extract.log"

:: Write version information
call :WriteVersionInfo "!MOD_AUTHOR!" "!MOD_NAME!" "!MOD_VERSION!"
if !errorlevel! neq 0 call :HandleError "Failed to write version information for !MOD_NAME!" 6

call :ColorEcho GREEN "✓ Successfully installed !MOD_NAME! v!MOD_VERSION!"
endlocal
exit /b 0

:: =================================
:: USER CONFIRMATION DIALOG
:: =================================
:: ======================================================================
:: FUNCTION: SHOW_MOD_LIST_AND_CONFIRM
:: PURPOSE: Display mod selection and obtain user consent
:: ======================================================================
:SHOW_MOD_LIST_AND_CONFIRM
setlocal EnableDelayedExpansion
del "%CONFIRMATION_FILE%" 2>nul

:: Display mod list header
call :ColorEcho CYAN "The following mods will be installed:"
echo.
call :ColorEcho WHITE "  - BepInExPack (Core Mod Loader) by BepInEx"

:: Iterate through configured modlist
for %%a in ("%MOD_LIST:;=";"%") do (
    for /f "tokens=1,2 delims=," %%b in ("%%~a") do (
        call :ColorEcho WHITE "  - %%b by %%c"
    )
)

:: User confirmation logic
:CONFIRM_LOOP
echo.
call :ColorEcho YELLOW "Install all listed mods? (Y/N)"
set /p "USER_INPUT= "
set "USER_INPUT=!USER_INPUT: =!"

:: Handle confirmation response
if /i "!USER_INPUT!"=="Y" (
    echo CONFIRMED > "%CONFIRMATION_FILE%"
    endlocal
    exit /b 0
) else if /i "!USER_INPUT!"=="N" (
    endlocal
    exit /b 1
) else (
    call :HandleError "Invalid confirmation input" 11
    goto :CONFIRM_LOOP
)

::==================================
:: Helper Functions (organized together)
::==================================

:: ======================================================================
:: FUNCTION: CREATE_DIRECTORY
:: PURPOSE: Safely create directories with error handling
:: ======================================================================
:CREATE_DIRECTORY
setlocal
set "DIR_PATH=%~1"
if not exist "%DIR_PATH%" (
    mkdir "%DIR_PATH%" 2>nul || (
        call :HandleError "Failed to create directory: %DIR_PATH%" 3
        endlocal
        exit /b 3
    )
)
endlocal
exit /b 0

:: ======================================================================
:: FUNCTION: Log
:: ======================================================================
:Log
setlocal EnableDelayedExpansion
set "MESSAGE=%~1"
set "CONSOLE=%~2"
echo [%date% %time%] !MESSAGE! >> "!LOG_FILE!"
if "!CONSOLE!"=="console" echo !MESSAGE!
endlocal
exit /b 0

:: ======================================================================
:: FUNCTION: ColorEcho
:: ======================================================================
:ColorEcho
setlocal EnableDelayedExpansion
set "COLOR=%~1"
set "MESSAGE=%~2"
if defined !COLOR! (
    echo !%COLOR%!!MESSAGE!!RESET!
) else (
    echo !MESSAGE!
)
endlocal
exit /b 0

:: ======================================================================
:: FUNCTION: HandleError
:: ======================================================================
:HandleError
setlocal EnableDelayedExpansion
set "ERROR_DESCRIPTION=%~1"
set "ERROR_CATEGORY_CODE=%~2"
set "ERROR_LOG=%~3"

:: Get error description from code
set "ERROR_CODE_DESC=!ERROR_CODE_%ERROR_CATEGORY_CODE%!"

:: Enhanced error formatting
call :Log "ERROR [!ERROR_CATEGORY_CODE!]: !ERROR_DESCRIPTION! (!ERROR_CODE_DESC!)" "console"
call :ColorEcho RED "X ERROR [!ERROR_CATEGORY_CODE!]: !ERROR_DESCRIPTION! (!ERROR_CODE_DESC!)"

:: Include log file contents if provided
if defined ERROR_LOG (
    if exist "!ERROR_LOG!" (
        call :Log "Additional error details from !ERROR_LOG!:" "console"
        type "!ERROR_LOG!" >> "!LOG_FILE!"
        call :Log "----------------------------------------" "console"
    )
)

:: Add troubleshooting context
call :Log "Troubleshooting steps:" "console"
call :Log "1. Verify internet connection" "console"
call :Log "2. Check antivirus/firewall settings" "console"
call :Log "3. Ensure sufficient disk space" "console"
call :Log "4. Retry with administrator privileges" "console"

endlocal & (
    set "INSTALL_STATUS=%ERROR_CATEGORY_CODE%"
    exit /b %ERROR_CATEGORY_CODE%
)

:: Environment initialization
:: Purpose: Verifies system requirements and prepares environment
:: Parameters: None
:: Globals Modified: Sets up TEMP_DIR, LOG_DIR, etc.
:: Error Codes:
::   0 - Success
::   1 - Missing requirements (PS version, disk space, etc.)
:InitializeEnvironment
setlocal EnableDelayedExpansion
call :ColorEcho BLUE "► Initializing installer..."
call :Log "Checking environment requirements..."

:: Configure UTF-8 code page
chcp 65001 >nul
call :Log "Set active code page to 65001 (UTF-8)"

:: Check PowerShell version
powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "if ($PSVersionTable.PSVersion.Major -lt 5) {" ^
            "throw 'PowerShell 5.0+ required' " ^
        "} " ^
    "} catch {" ^
        "$_.Exception | Out-File '!LOG_DIR!\ps_version_check.log';" ^
        "exit 1 " ^
    "}" >nul 2>&1
if !errorlevel! neq 0 (
    call :HandleError "PowerShell 5.0 or higher required" 1
    endlocal
    exit /b 1
)

:: Check internet connectivity
call :Log "Checking internet connectivity..."
powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "Test-NetConnection -ComputerName thunderstore.io -Port 443 " ^
    "} catch {" ^
        "$_.Exception | Out-File '!LOG_DIR!\connectivity_check.log';" ^
        "exit 1 " ^
    "}" >nul 2>&1
if !errorlevel! neq 0 (
    call :HandleError "No internet connection or Thunderstore.io unreachable" 2
    endlocal
    exit /b 2
)

:: Check available disk space
call :Log "Checking available disk space..."
powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "$drive = (Get-Item '%TEMP%').PSDrive;" ^
        "if ($drive.Free -lt 1GB) {" ^
            "throw 'Insufficient disk space' " ^
        "} " ^
    "} catch {" ^
        "$_.Exception | Out-File '!LOG_DIR!\space_check.log';" ^
        "exit 1 " ^
    "}" >nul 2>&1
if !errorlevel! neq 0 (
    call :HandleError "Insufficient disk space (1GB required)" 4
    endlocal
    exit /b 4
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
call :Log "Starting game location detection..."
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
        powershell -Command "$content = Get-Content -LiteralPath '!STEAM_PATH!\steamapps\libraryfolders.vdf';" ^
            "$paths = $content | Select-String -Pattern '^\s*""path""\s*""([^""]+)""' |" ^
                "ForEach-Object { $_.Matches.Groups[1].Value };" ^
            "$paths | ForEach-Object {" ^
                "$lcPath = ('{0}\steamapps\common\Lethal Company' -f $_) -replace '[\\/]+','\\';" ^
                "if (Test-Path -LiteralPath $lcPath) {" ^
                    "'{0}\steamapps\common\Lethal Company' -f $_" ^
                "}" ^
            "}" > "!TEMP_DIR!\steam_libs.txt"
        
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

:: ======================================================================
:: FUNCTION: ValidateGamePath
:: PURPOSE: Verifies game installation path validity
:: PARAMETERS: None
:: GLOBALS:
::   FOUND_PATH (validates) - Game directory path
:: ERROR CODES:
::   3 - Path validation failed (missing Lethal Company.exe)
:: NOTES:
::   - Triggers manual input fallback on failure
::   - Case-insensitive file existence check
:: ======================================================================
:ValidateGamePath
set "FOUND_PATH=!FOUND_PATH:"=!"
if "!FOUND_PATH:~-1!"=="\" set "FOUND_PATH=!FOUND_PATH:~0,-1!"
if not exist "!FOUND_PATH!\Lethal Company.exe" (
    call :Log "Invalid path: !FOUND_PATH!"
    call :HandleError "Lethal Company.exe not found at path" 13
    goto :ManualInput
)
call :ColorEcho GREEN "✓ Lethal Company install located at: !FOUND_PATH!"
call :Log "Valid game path found: !FOUND_PATH!"
endlocal & set "FOUND_PATH=%FOUND_PATH%"
exit /b 0

::==================================
:: More Helper Functions (continuing in required order)
::==================================

:: ========================================================================
:: FUNCTION: CreateBackup (proper scoping with variable preservation)
:: ========================================================================
:CreateBackup
setlocal EnableDelayedExpansion
call :ColorEcho BLUE "► Creating backup..."

set "BACKUP_DIR=%TEMP_DIR%\backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "BACKUP_DIR=%BACKUP_DIR: =0%"

:: Check if BepInEx exists
if exist "!FOUND_PATH!\BepInEx" (
    mkdir "!BACKUP_DIR!" 2>nul || (
        call :HandleError "Failed to create backup directory" 5
        goto :CreateBackup_End
    )

    :: Create backup with logging
    robocopy "!FOUND_PATH!\BepInEx" "!BACKUP_DIR!\BepInEx" /E /COPYALL /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\backup.log" >nul
    if !errorlevel! GEQ 8 (
        call :HandleError "Failed to create backup" 5 "!LOG_DIR!\backup.log"
        goto :CreateBackup_End
    )

    :: Also backup doorstop files if they exist
    if exist "!FOUND_PATH!\winhttp.dll" (
        robocopy "!FOUND_PATH!" "!BACKUP_DIR!" winhttp.dll /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\backup.log" >nul
    )
    if exist "!FOUND_PATH!\doorstop_config.ini" (
        robocopy "!FOUND_PATH!" "!BACKUP_DIR!" doorstop_config.ini /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\backup.log" >nul
    )

    call :Log "Created backup at: !BACKUP_DIR!" "console"
    call :ColorEcho GREEN "✓ Backup created successfully"
) else (
    call :Log "No existing BepInEx installation found, skipping backup" "console"
    call :ColorEcho YELLOW "No existing installation found to backup"
)

:CreateBackup_End
endlocal & (
    set "BACKUP_DIR=%BACKUP_DIR%"
    exit /b 0
)

:: ======================================================================
:: FUNCTION: RestoreBackup
:: PURPOSE: Restores BepInEx configuration from backup
:: PARAMETERS: None
:: GLOBALS:
::   BACKUP_DIR (reads) - Backup source location
::   FOUND_PATH (modifies) - Game installation directory
:: ERROR CODES:
::   5 - Restoration failure
:: NOTES:
::   - Uses robocopy for directory mirroring
::   - Preserves original backup on failure
:: ======================================================================
:RestoreBackup
setlocal EnableDelayedExpansion
call :ColorEcho BLUE "► Restoring backup..."

:: Verify backup exists
if not exist "!BACKUP_DIR!\BepInEx" (
    call :HandleError "Backup directory not found or invalid" 3
    goto :RestoreBackup_End
)

:: Remove current installation if it exists
if exist "!FOUND_PATH!\BepInEx" (
    rd /s /q "!FOUND_PATH!\BepInEx"
    if !errorlevel! neq 0 (
        call :HandleError "Failed to remove current installation" 8
        goto :RestoreBackup_End
    )
)

:: Restore BepInEx directory with robocopy
robocopy "!BACKUP_DIR!\BepInEx" "!FOUND_PATH!\BepInEx" /E /COPYALL /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\restore.log" >nul
if !errorlevel! GEQ 8 (
    call :HandleError "Failed to restore BepInEx directory" 1 "!LOG_DIR!\restore.log"
    goto :RestoreBackup_End
)

:: Restore doorstop files if they exist in backup
if exist "!BACKUP_DIR!\winhttp.dll" (
    robocopy "!BACKUP_DIR!" "!FOUND_PATH!" winhttp.dll /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\restore.log" >nul
)
if exist "!BACKUP_DIR!\doorstop_config.ini" (
    robocopy "!BACKUP_DIR!" "!FOUND_PATH!" doorstop_config.ini /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\restore.log" >nul
)

call :Log "Successfully restored from backup" "console"
call :ColorEcho GREEN "✓ Backup restored successfully"
:RestoreBackup_End
endlocal
exit /b 0

:: ======================================================================
:: FUNCTION: WriteVersionInfo
:: PURPOSE: Maintains mod version manifest for future updates
:: OUTPUT FORMAT:
::   - Author-ModName=Version in LCPlus_Versions.txt
:: SPECIAL CASES:
::   - Creates config directory if missing
::   - Preserves existing entries when updating
:: ======================================================================
:WriteVersionInfo
set "MOD_AUTHOR=%~1"
set "MOD_NAME=%~2"
set "MOD_VERSION=%~3"
set "VERSION_FILE=!FOUND_PATH!\BepInEx\config\LCPlus_Versions.txt"

:: Create config directory if it doesn't exist
call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\config" || (
    endlocal
    exit /b 6
)

:: Create or update version file with author-name combination
if not exist "!VERSION_FILE!" (
    echo !MOD_AUTHOR!-!MOD_NAME!=!MOD_VERSION!> "!VERSION_FILE!"
    if !errorlevel! neq 0 (
        call :HandleError "Failed to create version file"
        exit /b 1
    )
    exit /b 0
)

:: Create temporary file for version updates
if exist "!TEMP_CFG!" del /f /q "!TEMP_CFG!"
type nul > "!TEMP_CFG!" 2>nul
if !errorlevel! neq 0 (
    call :HandleError "Failed to create temporary file"
    exit /b 1
)

set "FOUND=0"
for /f "usebackq tokens=1,* delims==" %%a in ("!VERSION_FILE!") do (
    if "%%a"=="!MOD_AUTHOR!-!MOD_NAME!" (
        echo !MOD_AUTHOR!-!MOD_NAME!=!MOD_VERSION!>> "!TEMP_CFG!"
        set "FOUND=1"
    ) else (
        echo %%a=%%b>> "!TEMP_CFG!"
    )
)

if !FOUND!==0 (
    echo !MOD_AUTHOR!-!MOD_NAME!=!MOD_VERSION!>> "!TEMP_CFG!"
)

:: Only move if both files exist
if exist "!TEMP_CFG!" (
    move /y "!TEMP_CFG!" "!VERSION_FILE!" >nul
    if !errorlevel! neq 0 (
        call :HandleError "Failed to update version file"
        if exist "!TEMP_CFG!" del /f /q "!TEMP_CFG!"
        exit /b 1
    )
)

call :Log "Updated version information for !MOD_AUTHOR!/!MOD_NAME! to v!MOD_VERSION!"
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

call :Log "Downloading !MOD_NAME! from !URL!"
call :ColorEcho WHITE "* Downloading !MOD_NAME!..."

powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "$ProgressPreference = 'SilentlyContinue';" ^
        "$webClient = New-Object System.Net.WebClient;" ^
        "$webClient.Headers.Add('User-Agent', 'LCPlusInstaller/%VERSION%');" ^
        "$webClient.DownloadFile('!URL!', '!OUTPUT!')" ^
    "} catch {" ^
        "Write-Error (\"Download Failed: $_\");" ^
        "exit 1" ^
    "}" 2>"!LOG_DIR!\!MOD_NAME!_download.log"

if !errorlevel! neq 0 (
    call :HandleError "Download failed for !MOD_NAME! ([!URL!])" 2 "!LOG_DIR!\!MOD_NAME!_download.log"
    endlocal
    exit /b 2
)

if not exist "!OUTPUT!" (
    call :HandleError "Download file not found for !MOD_NAME!"
    endlocal
    exit /b 1
)

for %%A in ("!OUTPUT!") do (
    if %%~zA LEQ 0 (
        call :Log "ERROR: Downloaded file is empty for !MOD_NAME!"
        call :ColorEcho RED "ERROR: Download verification failed for !MOD_NAME!"
        del "!OUTPUT!" 2>nul
        endlocal
        exit /b 1
    )
)

call :Log "Successfully downloaded !MOD_NAME!"
endlocal
exit /b 0

:: ======================================================================
:: FUNCTION: ExtractAndInstallMod
:: PURPOSE: Handles mod file extraction and installation validation
:: CRITICAL CHECKS:
::   - Verifies DLL presence after installation
::   - Handles nested plugin folder structures
:: ERROR CONDITIONS:
::   - Empty/malformed zip files
::   - File copy permissions issues
:: ======================================================================
:ExtractAndInstallMod
setlocal EnableDelayedExpansion
set "ZIP_FILE=%~1"
set "EXTRACT_DIR=%~2"
set "MOD_NAME=%~3"
set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"
set "INSTALL_DIR=!FOUND_PATH!\BepInEx\plugins\!MOD_NAME!"
set "INSTALL_LOG=!LOG_DIR!\!MOD_NAME!_install.log"

call :Log "Extracting !MOD_NAME! from !ZIP_FILE! to !EXTRACT_DIR!"
call :ColorEcho WHITE "* Extracting files..."

:: Silent directory cleanup with full error suppression
if exist "!MOD_EXTRACT_DIR!" (
    rd /s /q "!MOD_EXTRACT_DIR!" >nul 2>&1
)

powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "Expand-Archive -Path '!ZIP_FILE!' -DestinationPath '!MOD_EXTRACT_DIR!' -Force;" ^
        "if (-not (Test-Path '!MOD_EXTRACT_DIR!\*')) { throw 'Empty extraction result' }" ^
    "} catch {" ^
        "Write-Error (\"Extraction Failed: $_\");" ^
        "exit 1" ^
    "}" 2>"!LOG_DIR!\!MOD_NAME!_extract.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to extract !MOD_NAME! (!ZIP_FILE!)" 9 "!LOG_DIR!\!MOD_NAME!_extract.log"
    endlocal
    exit /b 9
)

:: Silent directory creation
mkdir "!INSTALL_DIR!" >nul 2>&1
if not exist "!INSTALL_DIR!" (
    call :HandleError "Failed to create install directory: !INSTALL_DIR!"
    endlocal
    exit /b 1
)

:: Check for plugins folder and handle file copying accordingly
if exist "!MOD_EXTRACT_DIR!\plugins" (
    call :Log "Found plugins folder - performing structured copy"
    
    :: Copy plugins folder contents
    robocopy "!MOD_EXTRACT_DIR!\plugins" "!INSTALL_DIR!" /E /COPYALL /R:0 /W:0 /NP /LOG+:"!INSTALL_LOG!" >nul
    if !errorlevel! GEQ 8 (
        call :HandleError "Failed to copy plugins folder" 8 "!INSTALL_LOG!"
        endlocal
        exit /b 1
    )
    
    :: Copy remaining root files excluding plugins
    robocopy "!MOD_EXTRACT_DIR!" "!INSTALL_DIR!" /E /COPYALL /R:0 /W:0 /NP /XF plugins /LOG+:"!INSTALL_LOG!" >nul
    if !errorlevel! GEQ 8 (
        call :HandleError "Failed to copy root files" 8 "!INSTALL_LOG!"
        endlocal
        exit /b 1
    )
) else (
    call :Log "No plugins folder found - copying all files"
    
    :: Copy entire contents
    robocopy "!MOD_EXTRACT_DIR!" "!INSTALL_DIR!" /E /COPYALL /R:0 /W:0 /NP /LOG+:"!INSTALL_LOG!" >nul
    if !errorlevel! GEQ 8 (
        call :HandleError "Failed to copy mod files" 8 "!INSTALL_LOG!"
        endlocal
        exit /b 1
    )
)

dir /b "!INSTALL_DIR!\*.dll" >nul 2>&1
if !errorlevel! neq 0 (
    call :HandleError "No DLL files found in installed files for !MOD_NAME!"
    endlocal
    exit /b 1
)

exit /b 0
endlocal

::==================================
:: BepInEx Configuration Functions
::==================================

:: 10. Configure BepInEx installation
:ConfigureBepInEx
setlocal EnableDelayedExpansion
call :Log "Configuring BepInEx..." "console"
call :ColorEcho BLUE "► Configuring BepInEx..."

if not exist "!FOUND_PATH!\BepInEx\config" (
    mkdir "!FOUND_PATH!\BepInEx\config" 2>nul || (
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

call :Log "Installing mod: !MOD_AUTHOR!/!MOD_NAME!"
call :ColorEcho BLUE "► Installing !MOD_NAME!..."

:: API endpoint construction
set "THUNDERSTORE_API_ENDPOINT=https://thunderstore.io/api/experimental/package/!MOD_AUTHOR!/!MOD_NAME!/"
call :Log "DEBUG: Calling API URL: !THUNDERSTORE_API_ENDPOINT!"

:: Version tracking variables
set "MOD_VERSION="
set "DOWNLOAD_URL="

:: Fetch mod info with improved error handling and JSON depth
powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "$ProgressPreference = 'SilentlyContinue';" ^
        "$response = Invoke-RestMethod -Uri '!THUNDERSTORE_API_ENDPOINT!'" ^
            " -Method Get;" ^
        "$jsonResponse = $response | ConvertTo-Json -Depth 10;" ^
        "$jsonResponse | Out-File '!TEMP_DIR!\!MOD_NAME!_response.json'" ^
            " -Encoding UTF8;" ^
        "Write-Output ('VERSION=' + $response.latest.version_number);" ^
        "Write-Output ('URL=' + $response.latest.download_url)" ^
    "} catch {" ^
        "Write-Error $_.Exception.Message;" ^
        "exit 1" ^
    "}" > "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>"!LOG_DIR!\!MOD_NAME!_api_error.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to fetch mod info for !MOD_NAME!" 10 "!LOG_DIR!\!MOD_NAME!_api_error.log"
    endlocal
    exit /b 10
)

:: Parse version and URL using findstr
for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "MOD_VERSION=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "DOWNLOAD_URL=%%a"

:: Trim whitespace from parsed values
set "MOD_VERSION=!MOD_VERSION: =!"
set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

if not defined MOD_VERSION (
    call :Log "ERROR: Failed to parse version from API response"
    call :ColorEcho RED "ERROR: Invalid API response for !MOD_NAME!"
    endlocal
    exit /b 1
)

if not defined DOWNLOAD_URL (
    call :Log "ERROR: Failed to parse download URL from API response"
    call :ColorEcho RED "ERROR: Invalid API response for !MOD_NAME!"
    endlocal
    exit /b 1
)

:: Clean up temporary files
del "!TEMP_DIR!\!MOD_NAME!_response.json" 2>nul
del "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>nul

:: Setup paths with logging
set "ZIP_FILE=!TEMP_DIR!\!MOD_NAME!_v!MOD_VERSION!.zip"
set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"

:: Download mod files
call :DownloadMod "!DOWNLOAD_URL!" "!ZIP_FILE!" "!MOD_NAME!"
if !errorlevel! neq 0 call :HandleError "Download failed for !MOD_NAME!" 2 "!LOG_DIR!\!MOD_NAME!_download.log"

:: Extract and install
call :ExtractAndInstallMod "!ZIP_FILE!" "!MOD_EXTRACT_DIR!" "!MOD_NAME!"
if !errorlevel! neq 0 call :HandleError "Failed to extract !MOD_NAME! (!ZIP_FILE!)" 9 "!LOG_DIR!\!MOD_NAME!_extract.log"

:: Write version information
call :WriteVersionInfo "!MOD_AUTHOR!" "!MOD_NAME!" "!MOD_VERSION!"
if !errorlevel! neq 0 call :HandleError "Failed to write version information for !MOD_NAME!" 6

call :ColorEcho GREEN "✓ Successfully installed !MOD_NAME! v!MOD_VERSION!"
endlocal
exit /b 0

:: 14. Install BepInExPack
:INSTALL_BEPINEX_PACK
setlocal EnableDelayedExpansion
call :Log "Starting BepInExPack installation..."
call :ColorEcho BLUE "► Installing BepInExPack..."

:: Construct API URL
set "MOD_API_URL=https://thunderstore.io/api/experimental/package/BepInEx/BepInExPack/"
call :Log "DEBUG: Calling API URL: !MOD_API_URL!"

:: Fetch mod info
powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "$ProgressPreference = 'SilentlyContinue';" ^
        "$response = Invoke-RestMethod -Uri '!MOD_API_URL!' -Method Get;" ^
        "$jsonResponse = $response | ConvertTo-Json -Depth 10;" ^
        "$jsonResponse | Out-File '!TEMP_DIR!\BepInExPack_response.json' -Encoding UTF8;" ^
        "Write-Output ('VERSION=' + $response.latest.version_number);" ^
        "Write-Output ('URL=' + $response.latest.download_url)" ^
    "} catch {" ^
        "Write-Error $_.Exception.Message;" ^
        "exit 1" ^
    "}" > "!TEMP_DIR!\BepInExPack_api.txt" 2>"!LOG_DIR!\BepInExPack_api_error.log"

if !errorlevel! neq 0 (
    call :Log "ERROR: Failed to fetch BepInExPack info - Check !LOG_DIR!\BepInExPack_api_error.log"
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
if !errorlevel! neq 0 call :HandleError "Failed to download BepInExPack" 2 "!LOG_DIR!\BepInExPack_download.log"

:: Extract BepInExPack
call :Log "Extracting BepInExPack..." "console"
if exist "!MOD_EXTRACT_DIR!" rd /s /q "!MOD_EXTRACT_DIR!" >nul 2>&1
mkdir "!MOD_EXTRACT_DIR!" >nul 2>&1

powershell -Command "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
        "Expand-Archive -Path '!ZIP_FILE!'" ^
            " -DestinationPath '!MOD_EXTRACT_DIR!'" ^
            " -Force " ^
    "} catch {" ^
        "Write-Error $_.Exception.Message;" ^
        "exit 1 " ^
    "}" 2>"!LOG_DIR!\BepInExPack_extract.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to extract BepInExPack" 9 "!LOG_DIR!\BepInExPack_extract.log"
    endlocal
    exit /b 9
)

:: Set the correct source directory
set "SOURCE_DIR=!MOD_EXTRACT_DIR!\BepInExPack"
if not exist "!SOURCE_DIR!\BepInEx\*" (
    call :Log "ERROR: BepInEx folder not found in extracted BepInExPack contents"
    call :ColorEcho RED "ERROR: Invalid BepInExPack structure"
    endlocal
    exit /b 1
)

:: Copy the entire BepInEx folder to the game's root with robocopy
call :Log "Copying BepInEx files to: !FOUND_PATH!"
robocopy "!SOURCE_DIR!\BepInEx" "!FOUND_PATH!\BepInEx" /E /COPYALL /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\BepInExPack_install.log" >nul
if !errorlevel! GEQ 8 (
    call :Log "ERROR: Failed to copy BepInEx files"
    call :ColorEcho RED "ERROR: Installation failed"
    type "!LOG_DIR!\BepInExPack_install.log" >> "!LOG_FILE!"
    endlocal
    exit /b 1
)

:: Create plugins folder if it doesn't exist
if not exist "!FOUND_PATH!\BepInEx\plugins" (
    mkdir "!FOUND_PATH!\BepInEx\plugins"
    call :Log "Created missing BepInEx\plugins folder."
)

:: Copy additional root files (winhttp.dll, doorstop_config.ini, changelog.txt)
for %%a in ("winhttp.dll", "doorstop_config.ini", "changelog.txt") do (
    set "SOURCE_FILE=!SOURCE_DIR!\%%a"
    if exist "!SOURCE_FILE!" (
        call :Log "Copying !SOURCE_FILE! to game root"
        robocopy "!SOURCE_DIR!" "!FOUND_PATH!" "%%a" /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\BepInExPack_install.log" >nul
        if !errorlevel! GEQ 8 (
            call :Log "ERROR: Failed to copy file: %%a"
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

call :Log "BepInExPack installation completed successfully"
call :ColorEcho GREEN "✓ BepInExPack installed successfully"
endlocal
exit /b 0

::==================================
:: Cleanup and Error Handling
::==================================

:: ======================================================================
:: FUNCTION: CLEANUP
:: PURPOSE: Post-installation resource management
:: RETENTION POLICY:
::   - Preserves logs for troubleshooting
::   - Removes temporary extraction files
::   - Keeps backups until manual removal
:: ======================================================================
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
if exist "%CONFIRMATION_FILE%" (
    del "%CONFIRMATION_FILE%" && (
        call :Log "Cleaned up confirmation file"
    ) || (
        call :Log "WARNING: Failed to delete confirmation file" "console"
    )
)

endlocal

echo.
if %INSTALL_STATUS% equ 0 (
    call :ColorEcho CYAN "Thanks for using Lethal Company Plus!"
) else (
    call :ColorEcho RED "Installation encountered errors. See log for details."
)
call :ColorEcho CYAN "Press any key to exit..."
pause >nul
exit /b %INSTALL_STATUS%

:: ======================================================================
:: FUNCTION: INITIALIZE_DIRECTORIES
:: PURPOSE: Creates required temporary directories for installation
:: PARAMETERS: None
:: GLOBALS:
::   TEMP_DIR (creates) - Root temporary directory
::   LOG_DIR (creates) - Log storage directory
::   EXTRACT_DIR (creates) - Mod extraction workspace
:: ERROR CODES:
::   1 - Directory creation failure
:: NOTES:
::   - Creates nested directory structure with error handling
::   - Required for proper installer operation
:: ======================================================================
:INITIALIZE_DIRECTORIES
:: ... existing directory creation code ...

:: ======================================================================
:: FUNCTION: DownloadModlist
:: PURPOSE: Downloads and parses modlist.ini
:: ======================================================================
:DownloadModlist
setlocal EnableDelayedExpansion
:: Use Invoke-WebRequest to get content directly
powershell -Command "$webClient = New-Object System.Net.WebClient;" ^
    "$webClient.Headers.Add('User-Agent', 'LCPlusInstaller/%VERSION%');" ^
    "try { " ^
        "$content = $webClient.DownloadString(" ^
            "'https://raw.githubusercontent.com/PyroDonkey/Lethal-Company-Plus/main/Modlist/modlist.ini'" ^
        ") " ^
    "} catch { " ^
        "Write-Error $_.Exception.Message; " ^
        "exit 1 " ^
    "}; " ^
    "$content | Out-File '%TEMP_DIR%\\modlist.ini' -Encoding UTF8" ^
    2>"%LOG_DIR%\modlist_download.log"

if !errorlevel! neq 0 (
    call :HandleError "Failed to download modlist.ini" 2 "%LOG_DIR%\modlist_download.log"
    endlocal
    exit /b 2
)

if not exist "%TEMP_DIR%\modlist.ini" (
    call :HandleError "Downloaded modlist.ini not found" 3
    endlocal
    exit /b 3
)

set "MOD_LIST="
for /f "usebackq tokens=*" %%a in ("%TEMP_DIR%\modlist.ini") do (
    set "LINE=%%a"
    set "LINE=!LINE: =!"
    if not "!LINE!"=="" (
        if "!LINE:~0,1!" neq ";" (
            for /f "tokens=1,2 delims=," %%b in ("!LINE!") do (
                set "MOD_LIST=!MOD_LIST!%%b,%%c;"
            )
        )
    )
)
if not defined MOD_LIST (
    call :HandleError "No valid mods found in modlist.ini" 14
    endlocal
    exit /b 14
)
if defined MOD_LIST set "MOD_LIST=!MOD_LIST:~0,-1!"

endlocal & set "MOD_LIST=%MOD_LIST%"
exit /b 0

:: ======================================================================
:: NEW FUNCTION: InitializeLogging
:: ======================================================================
:InitializeLogging
echo [%date% %time%] Lethal Company Plus installation started > "%LOG_FILE%"
echo [%date% %time%] Initializing installer... >> "%LOG_FILE%"
exit /b 0