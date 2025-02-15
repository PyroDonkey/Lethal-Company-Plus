@echo off
setlocal EnableDelayedExpansion

:: =================================
:: Global Configuration
:: =================================
:: Core installation state tracking
set "INSTALL_STATUS = 0"
set "FOUND_PATH="
set "VERSION_FILE="
set "BACKUP_DIR="

:: Temporary workspace configuration
set "TEMP_DIR=%TEMP%\LCPlusInstall"
set "LOG_DIR=%TEMP_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\debug.log" 
set "EXTRACT_DIR=%TEMP_DIR%\extracted"
set "MOD_COUNT=0"

:: ANSI color control
set "ESC="
set "GREEN="
set "YELLOW="
set "RED="
set "BLUE="
set "CYAN="
set "WHITE="
set "RESET="

:: Version Information 
set "VERSION=1.6.2"
set "LAST_MODIFIED=2025-02-15"

:: Error code descriptions
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
set "CONFIRMATION_FILE=%TEMP_DIR%\install_confirmed.flag"

:: =================================
:: User Confirmation Dialog
:: =================================

:: ======================================================================
:: FUNCTION: CHECK_AND_REQUEST_ELEVATION
:: PURPOSE: Requests administrator privileges for installation
:: GLOBALS MODIFIED:
::   - INSTALL_STATUS (sets on elevation failure)
:: ERROR CODES:
::   12 - Elevation request failed
:: ======================================================================
:CHECK_AND_REQUEST_ELEVATION
    WHOAMI /GROUPS | findstr /b /c:"Mandatory Label\High Mandatory Level" >nul 2>&1
    if %errorlevel% equ 0 (
        goto :CONTINUE_INITIALIZATION
    )

    echo Requesting administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "& {Start-Process '%~f0' -Verb RunAs -ErrorAction Stop; exit $LASTEXITCODE}"

    if %errorlevel% neq 0 (
        call :HandleError "Elevation request failed" 12
        set INSTALL_STATUS=12
        goto :CLEANUP
    )
    exit /b 0

:: ======================================================================
:: FUNCTION: CONTINUE_INITIALIZATION
:: ======================================================================
:CONTINUE_INITIALIZATION
    call :CREATE_DIRECTORY "%TEMP_DIR%" || (
        call :HandleError "Failed to create temp directory: %TEMP_DIR%" 3
        set INSTALL_STATUS = 3
        goto :CLEANUP
    )
    
    call :CREATE_DIRECTORY "%LOG_DIR%" || (
        call :HandleError "Failed to create log directory: %LOG_DIR%" 3 
        set INSTALL_STATUS=3
        goto :CLEANUP
    )
    
    call :CREATE_DIRECTORY "%EXTRACT_DIR%" || (
        call :HandleError "Failed to create extraction directory: %EXTRACT_DIR%" 3
        set INSTALL_STATUS=3
        goto :CLEANUP
    )

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

:: =================================
:: Main Installation Flow
:: =================================
:START_INSTALLATION
    :: Core installation sequence
    call :InitializeEnvironment || (
        call :HandleError "Environment initialization failed" 1
        set INSTALL_STATUS=1
        goto :CLEANUP
    )

    call :LocateGame || (
        call :HandleError "Game location failed" 13
        set INSTALL_STATUS=13
        goto :CLEANUP
    )

    call :DownloadModlist || (
        call :HandleError "Failed to download/parse modlist.ini" 10
        set INSTALL_STATUS=10
        goto :CLEANUP
    )

    :: *** NEW: Recalculate MOD_COUNT ***
    set "MOD_COUNT=0"
    for %%a in ("%MOD_LIST:;=";"%") do set /a "MOD_COUNT += 1"

    call :SHOW_MOD_LIST_AND_CONFIRM || (
        call :Log "Installation cancelled by user" "console"
        call :ColorEcho YELLOW "Installation cancelled"
        set INSTALL_STATUS=11
        goto :CLEANUP
    )

    call :INSTALL_BEPINEX_PACK || (
        call :HandleError "BepInEx installation failed" 6
        set INSTALL_STATUS=6
        goto :CLEANUP
    )

    call :INSTALL_ALL_MODS || (
        call :HandleError "Mod installation failed" 14
        set INSTALL_STATUS=14
        goto :CLEANUP
    )

    goto :CLEANUP

:: ======================================================================
:: FUNCTION: INSTALL_ALL_MODS
:: ======================================================================
:INSTALL_ALL_MODS
    setlocal EnableDelayedExpansion
    call :ColorEcho BLUE "► Beginning mod installation..."
    echo.
    call :ColorEcho WHITE "Installing %MOD_COUNT% mods..."
    set "MOD_INDEX=0"

    :: Process each mod in the configured list
    for %%a in ("%MOD_LIST:;=";"%") do (
        for /f "tokens=1,2 delims=," %%b in ("%%~a") do (
            :: Skip core loader to prevent duplicate installation
            if /i not "%%b"=="BepInExPack" (
                call :InstallSingleMod "%%c" "%%b" "!MOD_INDEX!" || (
                    endlocal
                    exit /b %errorlevel%
                )
                set /a MOD_INDEX+=1
            )
        )
    )
    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: INSTALLSINGLEMOD
:: PURPOSE: Handles full installation process for a single mod
:: PARAMETERS:
::   %1 - MOD_AUTHOR (Thunderstore namespace)
::   %2 - MOD_NAME (Thunderstore package name)
::   %3 - MOD_INDEX (Installation order index)
:: GLOBALS: MOD_VERSION, DOWNLOAD_URL, ZIP_FILE, MOD_EXTRACT_DIR, INSTALL_DIR
:: ERROR CODES: 2,8,9,10 - Various installation failures
::===================================================================
:INSTALLSINGLEMOD
    setlocal EnableDelayedExpansion
    set "MOD_AUTHOR=%~1"
    set "MOD_NAME=%~2"
    set "MOD_INDEX=%~3"
    
    :: Create padded index for sorted load order
    set "MOD_INDEX_PADDED=0!MOD_INDEX!"
    set "MOD_INDEX_PADDED=!MOD_INDEX_PADDED:~-2!"

    :: Setup API endpoint
    set "THUNDERSTORE_API_ENDPOINT=https://thunderstore.io/api/experimental/package/!MOD_AUTHOR!/!MOD_NAME!/"
    call :Log "Fetching mod info from: !THUNDERSTORE_API_ENDPOINT!"

    :: API Request with error handling
    powershell -Command "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; try { $response = Invoke-RestMethod -Uri '!THUNDERSTORE_API_ENDPOINT!' -Method Get; Write-Output ('VERSION=' + $response.latest.version_number); Write-Output ('URL=' + $response.latest.download_url) } catch { Write-Error $_.Exception.Message; exit 1 }" > "!TEMP_DIR!\!MOD_NAME!_api.txt" 2>"!LOG_DIR!\!MOD_NAME!_api_error.log"

    if !errorlevel! neq 0 (
        call :HandleError "Failed to fetch mod info for !MOD_NAME!" 2 "!LOG_DIR!\!MOD_NAME!_api_error.log"
        endlocal
        exit /b 2
    )

    :: Parse version and URL from API response
    for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "MOD_VERSION=%%a"
    for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!TEMP_DIR!\!MOD_NAME!_api.txt"') do set "DOWNLOAD_URL=%%a"
    set "MOD_VERSION=!MOD_VERSION: =!"
    set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

    :: Validate parsed data
    if not defined MOD_VERSION (
        call :HandleError "Invalid API response: Missing version for !MOD_NAME!" 10
        endlocal
        exit /b 10
    )
    if not defined DOWNLOAD_URL (
        call :HandleError "Invalid API response: Missing URL for !MOD_NAME!" 10
        endlocal
        exit /b 10
    )

    :: Setup file paths
    set "ZIP_FILE=!TEMP_DIR!\!MOD_NAME!_v!MOD_VERSION!.zip"
    set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"
    set "INSTALL_DIR=!FOUND_PATH!\BepInEx\plugins\!MOD_INDEX_PADDED!_!MOD_NAME!"

    :: Download mod using PowerShell
    call :ColorEcho WHITE "* Downloading !MOD_NAME!..."
    powershell -Command "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; try { Invoke-WebRequest -Uri '!DOWNLOAD_URL!' -OutFile '!ZIP_FILE!' } catch { Write-Error $_.Exception.Message; exit 1 }" 2>"!LOG_DIR!\!MOD_NAME!_download.log"
    if !errorlevel! neq 0 (
        call :HandleError "Download failed for !MOD_NAME!" 2 "!LOG_DIR!\!MOD_NAME!_download.log"
        endlocal
        exit /b 2
    )

    :: Clean extract directory if it exists
    if exist "!MOD_EXTRACT_DIR!" rd /s /q "!MOD_EXTRACT_DIR!"

    :: Create fresh extract directory
    mkdir "!MOD_EXTRACT_DIR!" 2>nul || (
        call :HandleError "Failed to create extraction directory for !MOD_NAME!" 3
        endlocal
        exit /b 3
    )

        :: Display the extracting message
    call :ColorEcho WHITE "* Extracting !MOD_NAME!..."

    :: Extract mod
powershell -Command "$ErrorActionPreference = 'Stop'; try { Expand-Archive -Path '!ZIP_FILE!' -DestinationPath '!MOD_EXTRACT_DIR!' -Force } catch { Write-Error $_.Exception.Message; exit 1 }" 2>"!LOG_DIR!\!MOD_NAME!_extract.log"

    if !errorlevel! neq 0 (
        call :HandleError "Failed to extract !MOD_NAME!" 9 "!LOG_DIR!\!MOD_NAME!_extract.log"
        endlocal
        exit /b 9
    )

    :: Create installation directory
    if not exist "!INSTALL_DIR!" (
        mkdir "!INSTALL_DIR!" 2>nul || (
            call :HandleError "Failed to create installation directory for !MOD_NAME!" 8
            endlocal
            exit /b 8
        )
    )

    :: Initialize counter
    set "FILES_COPIED=0"

    :: Determine the base directory for installation
    set "SOURCE_BASE=!MOD_EXTRACT_DIR!"
    if exist "!MOD_EXTRACT_DIR!\BepInEx" (
        set "SOURCE_BASE=!MOD_EXTRACT_DIR!\BepInEx"
        set "INSTALL_BASE=!FOUND_PATH!\BepInEx"
        call :Log "Found BepInEx folder at root of mod; installing to game's BepInEx folder."
    ) else (
        set "INSTALL_BASE=!FOUND_PATH!"
        call :Log "No BepInEx folder found at root of mod; installing to game's root folder."
    )

    :: Process all files and flatten them into the mod directory
    for /f "delims=" %%F in ('dir /b /s /a-d "!MOD_EXTRACT_DIR!"') do (
        :: Get just filename without path
        for %%A in ("%%F") do set "FILE_NAME=%%~nxA"
        
        :: Patchers folder exception handling
        set "DEST_PATH=!INSTALL_DIR!\!FILE_NAME!"
        echo "%%F" | findstr /i "\\BepInEx\\Patchers\\" >nul
        if !errorlevel! equ 0 (
            set "PATCHERS_DIR=!FOUND_PATH!\BepInEx\Patchers"
            call :CREATE_DIRECTORY "!PATCHERS_DIR!" || (
                call :HandleError "Failed to create Patchers directory" 8
                endlocal
                exit /b 8
            )
            set "DEST_PATH=!PATCHERS_DIR!\!FILE_NAME!"
            call :Log "Found patcher file: !FILE_NAME! - redirecting to Patchers folder"
        )

        :: Copy file to appropriate destination
        call :Log "Copying !FILE_NAME! to !DEST_PATH!"
        copy /Y "%%F" "!DEST_PATH!" >nul
        
        :: Check copy error level
        if !errorlevel! equ 0 (
            set /a "FILES_COPIED+=1"
            call :Log "Successfully copied %%~nxF"
        ) else (
            call :Log "Copy failed (error !errorlevel!), attempting alternate copy method..."
            
            :: Use PowerShell with admin privileges for fallback
            powershell -Command "$ErrorActionPreference = 'Stop'; try { Copy-Item -Path '%%F' -Destination '!DEST_PATH!' -Force } catch { exit 1 }" 2>"!LOG_DIR!\!MOD_NAME!_copy_alt.log"

            if !errorlevel! equ 0 (
                set /a "FILES_COPIED+=1"
                call :Log "Alternate copy successful for %%~nxF"
            ) else (
                call :HandleError "Failed to copy %%~nxF (both methods failed)" 8
                endlocal
                exit /b 8
            )
        )
    )

    :: Verify installation
    if !FILES_COPIED! equ 0 (
        call :HandleError "No files were copied for !MOD_NAME!" 8
        endlocal
        exit /b 8
    )

    :: Record version information
    call :WriteVersionInfo "!MOD_AUTHOR!" "!MOD_NAME!" "!MOD_VERSION!"
    if !errorlevel! neq 0 (
        call :HandleError "Failed to write version info for !MOD_NAME!" 6
    )

    :: Clean up extracted files
    rd /s /q "!MOD_EXTRACT_DIR!" 2>nul

    call :ColorEcho GREEN "✓ Successfully installed !MOD_NAME! v!MOD_VERSION! ^(!FILES_COPIED! files^)"
    endlocal
    exit /b 0

:: ======================================================================
:: FUNCTION: SHOW_MOD_LIST_AND_CONFIRM
:: PURPOSE: Display mod selection and obtain user consent
:: PARAMETERS: None
:: GLOBALS: CONFIRMATION_FILE (creates/updates), MOD_COUNT (uses)
:: ERROR CODES: 11 - Invalid user input
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
    if /i "!USER_INPUT!" == "Y" (
        echo CONFIRMED > "%CONFIRMATION_FILE%"
        endlocal
        exit /b 0
    ) else if /i "!USER_INPUT!" == "N" (
        endlocal
        exit /b 1
    ) else (
        call :HandleError "Invalid confirmation input" 11
        goto :CONFIRM_LOOP
    )

:: ======================================================================
:: FUNCTION: CREATE_DIRECTORY
:: PURPOSE: Safely create directories with error handling
:: PARAMETERS:
::   %1 - Directory path to create
:: GLOBALS USED:
::   - LOG_FILE (appends creation attempts)
:: ERROR CODES:
::   3 - Directory creation failure
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
:: FUNCTION: LOG
:: PURPOSE: Writes messages to log file and/or console
:: PARAMETERS:
::   %1 - Message text
::   %2 - "console" to also display in console
:: GLOBALS MODIFIED:
::   - LOG_FILE (appends messages)
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
:: FUNCTION: COLORECHO
:: PURPOSE: Outputs colored text to console when supported
:: PARAMETERS:
::   %1 - Color name (GREEN/YELLOW/RED/etc)
::   %2 - Message text
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
:: FUNCTION: HANDLEERROR
:: PURPOSE: Centralized error handling and reporting
:: PARAMETERS:
::   %1 - Error description
::   %2 - Error category code
::   %3 - Optional log file path
:: GLOBALS MODIFIED:
::   - INSTALL_STATUS (sets global error state)
::   - LOG_FILE (appends error details)
:: ERROR CODES: 
::   Propagates received error code
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

:: ======================================================================
:: FUNCTION: INITIALIZEENVIRONMENT
:: PURPOSE: Verifies system requirements and prepares environment
:: PARAMETERS: None
:: GLOBALS: TEMP_DIR, LOG_DIR, EXTRACT_DIR (sets paths)
:: ERROR CODES: 1 - Missing requirements
:: ======================================================================
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

::======================================================================
:: FUNCTION: LocateGame
:: PURPOSE: Enhanced game installation path detection with debug output
:: GLOBALS MODIFIED:
::   - FOUND_PATH (sets on success)
:: ERROR CODES:
::   13 - Game not found/invalid path
::======================================================================
:LocateGame
    setlocal EnableDelayedExpansion
    set "FOUND_PATH="
    
    call :Log "Starting game location detection..." "console"
    call :ColorEcho BLUE "► Searching for Lethal Company installation..."
    echo.

    call :Log "DEBUG: Starting registry checks..."
    
    :: Check Steam registry locations
    for %%A in (
        "HKEY_CURRENT_USER\Software\Valve\Steam"
        "HKEY_LOCAL_MACHINE\Software\Valve\Steam"
        "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Valve\Steam"
    ) do (
        call :Log "DEBUG: Processing registry path: %%~A"
        reg query %%~A /v "InstallPath" >nul 2>&1
        set "REG_RESULT=!errorlevel!"
        call :Log "DEBUG: reg query result: !REG_RESULT!"
        
        if !REG_RESULT! equ 0 (
            call :Log "DEBUG: Found registry key, attempting to get value..."
            for /f "tokens=2,*" %%B in ('reg query %%~A /v "InstallPath" 2^>nul') do (
                call :Log "DEBUG: Registry value found: %%C"
                set "CHECK_PATH=%%C\steamapps\common\Lethal Company"
                call :Log "DEBUG: Checking path: !CHECK_PATH!"
                
                if exist "!CHECK_PATH!\Lethal Company.exe" (
                    call :Log "DEBUG: Found game executable"
                    set "FOUND_PATH=!CHECK_PATH!"
                    goto :ValidateAndSet
                ) else (
                    call :Log "DEBUG: Game executable not found at !CHECK_PATH!"
                )
                
                if exist "%%C\steamapps\libraryfolders.vdf" (
                    call :Log "DEBUG: Found libraryfolders.vdf, checking additional locations..."
                    
                    set "VDF_PATH=%%C\steamapps\libraryfolders.vdf"
                    call :Log "DEBUG: VDF path: !VDF_PATH!"
                    
                    powershell -Command "$content = Get-Content -LiteralPath '!VDF_PATH!'; $content | Select-String -Pattern 'path' -Context 0,1"
                    call :Log "DEBUG: PowerShell VDF check complete"
                )
            )
        ) else (
            call :Log "DEBUG: Registry key not found: %%~A (Error: !REG_RESULT!)"
        )
    )

    call :Log "DEBUG: Registry search complete, checking common locations..."

    :: Search common installation locations
    for %%D in (C D E F G) do (
        if exist "%%D:\" (
            call :Log "DEBUG: Checking drive %%D:"
            for %%P in (
                "\Program Files\Steam\steamapps\common\Lethal Company"
                "\Program Files (x86)\Steam\steamapps\common\Lethal Company"
                "\Steam\steamapps\common\Lethal Company"
                "\SteamLibrary\steamapps\common\Lethal Company"
                "\Games\Steam\steamapps\common\Lethal Company"
            ) do (
                set "CHECK_PATH=%%D:%%P"
                call :Log "DEBUG: Checking path: !CHECK_PATH!"
                if exist "!CHECK_PATH!\Lethal Company.exe" (
                    call :Log "DEBUG: Found game at !CHECK_PATH!"
                    set "FOUND_PATH=!CHECK_PATH!"
                    goto :ValidateAndSet
                )
            )
        )
    )

    call :Log "DEBUG: Automatic detection failed, prompting for manual input..."

    :: Manual input if automatic detection fails
    :ManualInput
    call :ColorEcho YELLOW "Unable to automatically locate Lethal Company."
    echo.
    call :ColorEcho WHITE "Please enter the full path to your Lethal Company installation"
    call :ColorEcho WHITE "(The folder containing 'Lethal Company.exe'):"
    echo.
    set /p "USER_PATH=Path: "
    
    if not defined USER_PATH (
        call :Log "DEBUG: No path entered"
        call :ColorEcho RED "No path entered."
        goto :ManualInput
    )
    
    call :Log "DEBUG: User entered path: !USER_PATH!"
    set "FOUND_PATH=!USER_PATH:"=!"
    
:ValidateAndSet
    call :Log "DEBUG: Entering validation phase..."
    
    :: Remove trailing slash if present
    if "!FOUND_PATH:~-1!" == "\" (
        set "FOUND_PATH=!FOUND_PATH:~0,-1!"
        call :Log "DEBUG: Removed trailing slash"
    )
    
    call :Log "DEBUG: Validating path: '!FOUND_PATH!'"
    
    :: Check for game executable
    if exist "!FOUND_PATH!\Lethal Company.exe" (
        call :Log "DEBUG: Game executable found"
    ) else (
        call :Log "DEBUG: Game executable not found at: '!FOUND_PATH!\Lethal Company.exe'"
        goto :ManualInput
    )

    :: Validate critical game files
    set "MISSING_FILES="
    set "MISSING_COUNT=0"
    
    call :Log "DEBUG: Checking critical files..."
    
    if not exist "!FOUND_PATH!\UnityPlayer.dll" (
        set "MISSING_FILES=!MISSING_FILES! UnityPlayer.dll"
        set /a "MISSING_COUNT+=1"
        call :Log "DEBUG: Missing UnityPlayer.dll"
    )
    if not exist "!FOUND_PATH!\UnityCrashHandler64.exe" (
        set "MISSING_FILES=!MISSING_FILES! UnityCrashHandler64.exe"
        set /a "MISSING_COUNT+=1"
        call :Log "DEBUG: Missing UnityCrashHandler64.exe"
    )
    
    if defined MISSING_FILES (
        call :Log "WARNING: Missing !MISSING_COUNT! critical game files:!MISSING_FILES!"
        call :ColorEcho YELLOW "Warning: !MISSING_COUNT! critical game files appear to be missing. Installation may be corrupted."
    )

    call :Log "DEBUG: Validation complete"
    call :ColorEcho GREEN "✓ Lethal Company found at: '!FOUND_PATH!'"
    call :Log "Successfully located game at: '!FOUND_PATH!'"
    
    endlocal & set "FOUND_PATH=%FOUND_PATH%"
    exit /b 0
    
:: ========================================================================
:: FUNCTION: CREATEBACKUP
:: PURPOSE: Creates backup of existing BepInEx installation
:: PARAMETERS: None
:: GLOBALS: BACKUP_DIR (sets backup location)
:: ERROR CODES: 5 - Backup creation failure
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
        call :Log "ERROR: Failed to restore BepInEx directory"
        call :ColorEcho RED "ERROR: Installation failed"
        type "!LOG_DIR!\restore.log" >> "!LOG_FILE!"
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
:: PARAMETERS:
::   %1 - Mod author
::   %2 - Mod name
::   %3 - Mod version
:: GLOBALS MODIFIED:
::   - VERSION_FILE (updates version information)
:: ERROR CODES:
::   8 - File write failure
:: NOTES:
::   - Creates config directory if missing
:: ======================================================================
:WriteVersionInfo
    setlocal EnableDelayedExpansion
    set "MOD_AUTHOR=%~1"
    set "MOD_NAME=%~2"
    set "MOD_VERSION=%~3"
    set "VERSION_FILE=!FOUND_PATH!\BepInEx\config\LCPlus_Versions.txt"
    set "TEMP_CFG=!TEMP_DIR!\version_temp.cfg"

    :: Create config directory if it doesn't exist
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\config" || (
        endlocal
        exit /b 6
    )

    :: Create or update version file with author-name combination
    if not exist "!VERSION_FILE!" (
        echo !MOD_AUTHOR!-!MOD_NAME!=!MOD_VERSION!> "!VERSION_FILE!"
        if !errorlevel! neq 0 (
            call :HandleError "Failed to create version file" 8
            endlocal
            exit /b 8
        )
        exit /b 0
    )

    :: Create temporary file for version updates
    if exist "!TEMP_CFG!" del /f /q "!TEMP_CFG!"
    type nul > "!TEMP_CFG!" 2>nul
    if !errorlevel! neq 0 (
        call :HandleError "Failed to create temporary file"
        endlocal
        exit /b 1
    )

    set "FOUND=0"
    for /f "usebackq tokens=1,* delims==" %%a in ("!VERSION_FILE!") do (
        if "%%a" == "!MOD_AUTHOR!-!MOD_NAME!" (
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
    endlocal
    exit /b 0

:: ======================================================================
:: FUNCTION: DownloadFile
:: PURPOSE: Core file download logic with error handling
:: PARAMETERS:
::   %1 - Source URL
::   %2 - Output file path
:: ERROR CODES:
::   2 - Download failure
:: ======================================================================
:DownloadFile
    setlocal EnableDelayedExpansion
    set "URL=%~1"
    set "OUTPUT=%~2"

    powershell -Command "$ErrorActionPreference = 'Stop';" ^
        "try {" ^
            "$ProgressPreference = 'SilentlyContinue';" ^
            "$webClient = New-Object System.Net.WebClient;" ^
            "$webClient.Headers.Add('User-Agent', 'LCPlusInstaller/%VERSION%');" ^
            "$webClient.DownloadFile('!URL!', '!OUTPUT!')" ^
        "} catch {" ^
            "Write-Error (\"Download Failed: $_\");" ^
            "exit 1" ^
        "}"
    
    if !errorlevel! neq 0 (
        endlocal
        exit /b 2
    )
    
    endlocal
    exit /b 0

:: ======================================================================
:: FUNCTION: DownloadMod
:: ======================================================================
:DownloadMod
    setlocal EnableDelayedExpansion
    set "URL=%~1"
    set "OUTPUT=%~2"
    set "MOD_NAME=%~3"

    call :Log "Downloading !MOD_NAME! from !URL!"
    call :ColorEcho WHITE "* Downloading !MOD_NAME!..."

    :: Use new centralized DownloadFile function
    call :DownloadFile "!URL!" "!OUTPUT!" 2>"!LOG_DIR!\!MOD_NAME!_download.log"

    :: Check for download errors
    if !errorlevel! neq 0 (
        call :HandleError "Download failed for !MOD_NAME! ([!URL!])" 2 "!LOG_DIR!\!MOD_NAME!_download.log"
        endlocal
        exit /b 2
    )

    :: Verify downloaded file exists and has content
    if not exist "!OUTPUT!" (
        call :HandleError "Download file not found for !MOD_NAME!"
        endlocal
        exit /b 1
    )
    
    :: Zero-byte file check
    for %%A in ("!OUTPUT!") do (
        if %%~zA LEQ 0 (
            call :HandleError "Empty download file for !MOD_NAME!" 2
            del "!OUTPUT!" 2>nul
            endlocal
            exit /b 2
        )
    )

    call :Log "Successfully downloaded !MOD_NAME!"
    endlocal
    exit /b 0

:: ======================================================================
:: FUNCTION: ConfigureBepInEx
:: ======================================================================
:ConfigureBepInEx
    setlocal EnableDelayedExpansion
    call :Log "Configuring BepInEx..." "console"
    call :ColorEcho BLUE "► Configuring BepInEx..."

    :: Create config directory if missing
    if not exist "!FOUND_PATH!\BepInEx\config" (
        mkdir "!FOUND_PATH!\BepInEx\config" 2>nul || (
            call :HandleError "Failed to create BepInEx config directory" 6
            endlocal
            exit /b 6
        )
    )

    set "BEPINEX_CFG=!FOUND_PATH!\BepInEx\config\BepInEx.cfg"
    
    :: Determine configuration mode
    if exist "!BEPINEX_CFG!" (
        call :ConfigureBepInExInternal 0
    ) else (
        call :ConfigureBepInExInternal 1
    )
    if !errorlevel! neq 0 (
        endlocal
        exit /b 1
    )

    call :ColorEcho GREEN "✓ BepInEx configuration complete"
    endlocal
    exit /b 0

:: ======================================================================
:: FUNCTION: ConfigureBepInExInternal
:: PURPOSE: Core configuration logic with mode selection
:: PARAMETERS: %1 - CREATE_DEFAULT (1=true/0=false)
:: ======================================================================
:ConfigureBepInExInternal
    setlocal EnableDelayedExpansion
    set "CREATE_DEFAULT=%~1"
    set "TEMP_CFG=!TEMP_DIR!\BepInEx.cfg.tmp"

    if !CREATE_DEFAULT! equ 1 (
        call :Log "Creating default configuration..."
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
        ) > "!BEPINEX_CFG!" 2>"!LOG_DIR!\bepinex_config.log"
        
        if !errorlevel! neq 0 (
            call :HandleError "Config creation failed" 6
            endlocal
            exit /b 6
        )
    ) else (
        call :Log "Updating existing configuration..."
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
                if !IN_LOGGING_CONSOLE! equ 1 (
                    if "!LINE:~0,8!"=="Enabled " (
                        echo Enabled = true
                    ) else (
                        echo !LINE!
                    )
                ) else if !IN_LOADING! equ 1 (
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
        if !CONSOLE_FOUND! equ 0 (
            echo.
            echo [Logging.Console]
            echo Enabled = true
        )
        if !LOADING_FOUND! equ 0 (
            echo.
            echo [Loading]
            echo LoadPlugins = true
        )) > "!TEMP_CFG!"

        move /y "!TEMP_CFG!" "!BEPINEX_CFG!" >nul
        if !errorlevel! neq 0 (
            call :HandleError "Config update failed" 6
            endlocal
            exit /b 6
        )
    )
    endlocal
    exit /b 0

:: ======================================================================
:: FUNCTION: INSTALL_BEPINEX_PACK 
:: ======================================================================
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
        exit /b 2
    )

    :: Parse version and URL
    for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!TEMP_DIR!\BepInExPack_api.txt"') do set "VERSION=%%a"
    for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!TEMP_DIR!\BepInExPack_api.txt"') do set "DOWNLOAD_URL=%%a"
    set "VERSION=!VERSION: =!"
    set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

    :: Setup paths
    set "ZIP_FILE=!TEMP_DIR!\BepInExPack_v!VERSION!.zip"
    set "EXTRACT_ROOT=!EXTRACT_DIR!\BepInEx"
    set "SOURCE_DIR=!EXTRACT_ROOT!\BepInExPack"

    :: Download BepInExPack using centralized function
    call :Log "Downloading BepInExPack from: !DOWNLOAD_URL!"
    call :ColorEcho WHITE "* Downloading BepInExPack..."
    call :DownloadFile "!DOWNLOAD_URL!" "!ZIP_FILE!" 2>"!LOG_DIR!\BepInExPack_download.log"

    if !errorlevel! neq 0 (
        call :HandleError "Failed to download BepInExPack" 2 "!LOG_DIR!\BepInExPack_download.log"
        endlocal
        exit /b 2
    )

    :: Verify downloaded file
    if not exist "!ZIP_FILE!" (
        call :HandleError "BepInExPack download file not found" 3
        endlocal
        exit /b 3
    )

    :: Zero-byte file check
    for %%A in ("!ZIP_FILE!") do (
        if %%~zA LEQ 0 (
            call :HandleError "Empty BepInExPack download file" 2
            del "!ZIP_FILE!" 2>nul
            endlocal
            exit /b 2
        )
    )

    :: Extract BepInExPack using :ExtractFiles
    call :Log "Extracting BepInExPack..." "console"
    if exist "!EXTRACT_ROOT!" rd /s /q "!EXTRACT_ROOT!" >nul 2>&1
    call :ExtractFiles "!ZIP_FILE!" "!EXTRACT_ROOT!" "BepInExPack"
    if !errorlevel! neq 0 (
        call :HandleError "Failed to extract BepInExPack" 9 "!LOG_DIR!\BepInExPack_extract.log"
        endlocal
        exit /b 9
    )

    :: Copy the *contents* of the BepInEx folder.
    call :Log "Copying BepInEx files to: !FOUND_PATH!"
    robocopy "!SOURCE_DIR!\BepInEx" "!FOUND_PATH!\BepInEx" /E /COPYALL /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\BepInExPack_install.log" >nul
    if !errorlevel! GEQ 8 (
        call :Log "ERROR: Failed to copy BepInEx files"
        call :ColorEcho RED "ERROR: Installation failed"
        type "!LOG_DIR!\BepInExPack_install.log" >> "!LOG_FILE!"
        endlocal
        exit /b 8
    )

    :: Copy winhttp.dll, doorstop_config.ini and changelog.txt to the game root directory
    robocopy "!SOURCE_DIR!" "!FOUND_PATH!" "winhttp.dll" "doorstop_config.ini" "changelog.txt" /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\BepInExPack_install.log" >nul
    if !errorlevel! GEQ 8 (
        call :Log "ERROR: Failed to copy BepInEx root files"
        call :ColorEcho RED "ERROR: Installation failed"
        type "!LOG_DIR!\BepInExPack_install.log" >> "!LOG_FILE!"
        endlocal
        exit /b 8
    )

    :: Create plugins folder (if it doesn't exist)
    if not exist "!FOUND_PATH!\BepInEx\plugins" (
        mkdir "!FOUND_PATH!\BepInEx\plugins"
        call :Log "Created missing BepInEx\plugins folder."
    )

    :: Configure BepInEx
    call :ConfigureBepInEx
    if !errorlevel! neq 0 (
        endlocal
        exit /b 6
    )

    call :Log "BepInExPack installation completed successfully"
    call :ColorEcho GREEN "✓ BepInExPack installed successfully"
    endlocal
    exit /b 0

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

    :: Clean up all log files except debug.log
    for %%a in ("%LOG_DIR%\*.log") do (
        set "file_name=%%~nxa"
        if /i not "!file_name!"=="debug.log" (
            del /f /q "%%a" 2>nul
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
:: FUNCTION: DownloadModlist
:: PURPOSE: Downloads and parses modlist.ini
:: ======================================================================
:DownloadModlist
    setlocal EnableDelayedExpansion
    :: Delete existing modlist before download
    del "%TEMP_DIR%\modlist.ini" 2>nul
    :: Use Invoke-WebRequest to get content directly
    powershell -Command "$webClient = New-Object System.Net.WebClient;" ^
        "$webClient.Headers.Add('User-Agent', 'LCPlusInstaller/%VERSION%');" ^
        "try { " ^
            "$content = $webClient.DownloadString(" ^
                "'https://raw.githubusercontent.com/PyroDonkey/Lethal-Company-Plus/refs/heads/main/Modlist/modlist.ini'" ^
            "); " ^
            "[System.IO.File]::WriteAllText('%TEMP_DIR%\\modlist.ini', $content)" ^
        "} catch { " ^
            "Write-Error $_.Exception.Message; " ^
            "exit 1 " ^
        "}; " ^
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
:: FUNCTION: InitializeLogging
:: ======================================================================
:InitializeLogging
    echo [%date% %time%] Lethal Company Plus installation started > "%LOG_FILE%"
    echo [%date% %time%] Initializing installer... >> "%LOG_FILE%"
    exit /b 0

:: ======================================================================
:: FUNCTION: EXTRACTFILES
:: PURPOSE: Handles archive extraction with validation
:: PARAMETERS:
::   %1 - Source archive path
::   %2 - Destination directory
::   %3 - Mod name (for logging)
:: GLOBALS MODIFIED:
::   - LOG_FILE (appends extraction details)
:: ERROR CODES:
::   9 - Extraction failure
:: NOTES:
::   - Supports ZIP format only
::   - Verifies extracted file structure
:: ======================================================================
:ExtractFiles
    setlocal EnableDelayedExpansion
    set "ZIP_FILE=%~1"
    set "DESTINATION_DIR=%~2"
    set "MOD_NAME=%~3"

    if defined MOD_NAME (
        call :ColorEcho WHITE "* Extracting !MOD_NAME!..."
        call :Log "Extracting !MOD_NAME! to !DESTINATION_DIR!"
    ) else (
        call :ColorEcho WHITE "* Extracting files..."
        call :Log "Extracting !ZIP_FILE! to !DESTINATION_DIR!"
    )

    :: Ensure extraction directory exists
    if not exist "!DESTINATION_DIR!" (
        mkdir "!DESTINATION_DIR!" 2>nul || (
            call :HandleError "Failed to create extraction directory: !DESTINATION_DIR!" 3
            endlocal
            exit /b 3
        )
    )

    :: Use PowerShell's Expand-Archive for better Unicode support
    powershell -Command "$ErrorActionPreference = 'Stop';" ^
        "try {" ^
            "Expand-Archive -Path '!ZIP_FILE!'" ^
                " -DestinationPath '!DESTINATION_DIR!'" ^
                " -Force " ^
        "} catch {" ^
            "Write-Error $_.Exception.Message;" ^
            "exit 9 " ^
        "}" 2>"!LOG_DIR!\!~n2_extract.log"

    if !errorlevel! neq 0 (
        call :HandleError "Extraction failed: !ZIP_FILE!" 9
        endlocal
        exit /b 9
    )

    endlocal
    exit /b 0