@echo off
setlocal EnableDelayedExpansion

:: =================================
:: Initialization Entry Point
:: =================================
call :InitializeConfig

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
set "VERSION=1.8.1"
set "LAST_MODIFIED=2025-02-19"

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

:: Temporary working variables
set "CONFIRMATION_FILE=%TEMP_DIR%\install_confirmed.flag"

::===================================================================
:: FUNCTION: CHECK_AND_REQUEST_ELEVATION
:: Requests and verifies admin privileges
:: MODIFIES: INSTALL_STATUS
:: RETURNS: 0=Success, 12=ElevationFailed
::===================================================================
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

::===================================================================
:: FUNCTION: INITIALIZECONFIG
:: Centralized configuration management
:: MODIFIES: All global configuration variables
::===================================================================
:InitializeConfig
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

    :: Version Information 
    set "VERSION=1.8.0"
    set "LAST_MODIFIED=2025-02-17"

    :: ANSI color control (initialized empty, populated later)
    set "ESC="
    set "GREEN="
    set "YELLOW="
    set "RED="
    set "BLUE="
    set "CYAN="
    set "WHITE="
    set "RESET="

    :: Load error code definitions
    call :DefineErrorCodes
exit /b 0

::===================================================================
:: FUNCTION: DEFINEERRORCODES
:: Centralized error code definitions
::===================================================================
:DefineErrorCodes
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
exit /b 0

::===================================================================
:: FUNCTION: CONTINUE_INITIALIZATION
:: Sets up working directories and environment
:: MODIFIES: INSTALL_STATUS
:: RETURNS: 0=Success, 3=DirectoryError
::===================================================================
:CONTINUE_INITIALIZATION
    call :CREATE_DIRECTORY "%TEMP_DIR%" || (
        call :HandleError "Failed to create temp directory: %TEMP_DIR%" 3
        set INSTALL_STATUS=3
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

::===================================================================
:: FUNCTION: INSTALL_ALL_MODS
:: Processes and installs all configured mods
:: USES: MOD_LIST, MOD_COUNT
:: RETURNS: 0=Success, Various error codes from InstallSingleMod
::===================================================================
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
:: FUNCTION: InstallSingleMod
:: Handles installation of individual mod
:: PARAMS: %1=Author, %2=ModName, %3=Index
:: RETURNS: 0=Success, Various installation error codes
::===================================================================
:INSTALLSINGLEMOD
    setlocal EnableDelayedExpansion
    set "MOD_AUTHOR=%~1"
    set "MOD_NAME=%~2"
    set "MOD_INDEX=%~3"
    
    :: Create padded index for sorted load order
    set "MOD_INDEX_PADDED=0!MOD_INDEX!"
    set "MOD_INDEX_PADDED=!MOD_INDEX_PADDED:~-2!"

    :: Use centralized API helper to get version info
    set "API_OUTPUT=%TEMP_DIR%\!MOD_NAME!_api.txt"
    call :CALL_THUNDERSTORE_API "!MOD_AUTHOR!" "!MOD_NAME!" "!API_OUTPUT!"
    if !errorlevel! neq 0 (
        endlocal
        exit /b !errorlevel!
    )

    :: Parse version and URL
    for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!API_OUTPUT!"') do set "MOD_VERSION=%%a"
    for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!API_OUTPUT!"') do set "DOWNLOAD_URL=%%a"
    set "MOD_VERSION=!MOD_VERSION: =!"
    set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

    :: Setup file paths
    set "ZIP_FILE=!TEMP_DIR!\!MOD_NAME!_v!MOD_VERSION!.zip"
    set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"
    set "INSTALL_DIR=!FOUND_PATH!\BepInEx\plugins\!MOD_INDEX_PADDED!_!MOD_NAME!"

    :: Download mod using centralized download function
    call :ColorEcho WHITE "* Downloading !MOD_NAME!..."
    call :DownloadFile "!DOWNLOAD_URL!" "!ZIP_FILE!" 2>"!LOG_DIR!\!MOD_NAME!_download.log"
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
    powershell -Command "$ErrorActionPreference = 'Stop';" ^
        "try {" ^
            "Expand-Archive -Path '!ZIP_FILE!'" ^
            " -DestinationPath '!MOD_EXTRACT_DIR!'" ^
            " -Force" ^
        "} catch {" ^
            "Write-Error $_.Exception.Message;" ^
            "exit 1" ^
        "}" 2>"!LOG_DIR!\!MOD_NAME!_extract.log"

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
            powershell -Command "$ErrorActionPreference = 'Stop';" ^
                "try {" ^
                    "Copy-Item -Path '%%F'" ^
                    " -Destination '!DEST_PATH!'" ^
                    " -Force" ^
                "} catch {" ^
                    "exit 1" ^
                "}" 2>"!LOG_DIR!\!MOD_NAME!_copy_alt.log"

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

::===================================================================
:: FUNCTION: SHOW_MOD_LIST_AND_CONFIRM
:: Displays mods and gets user confirmation
:: MODIFIES: CONFIRMATION_FILE
:: RETURNS: 0=Confirmed, 1=Cancelled, 11=InvalidInput
::===================================================================
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

::===================================================================
:: FUNCTION: CREATE_DIRECTORY
:: Creates directory with error handling
:: PARAMS: %1=DirectoryPath
:: RETURNS: 0=Success, 3=CreateError
::===================================================================
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

::===================================================================
:: FUNCTION: Log
:: Writes messages to log file and optionally console
:: PARAMS: %1=Message, %2=ConsoleFlag
:: USES: LOG_FILE
::===================================================================
:Log
    setlocal EnableDelayedExpansion
    set "MESSAGE=%~1"
    set "CONSOLE=%~2"
    echo [%date% %time%] !MESSAGE! >> "!LOG_FILE!"
    if "!CONSOLE!"=="console" echo !MESSAGE!
    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: ColorEcho
:: Outputs colored text when supported
:: PARAMS: %1=Color, %2=Message
::===================================================================
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

::===================================================================
:: FUNCTION: HandleError
:: Processes and logs error conditions
:: PARAMS: %1=Description, %2=Code, %3=LogFile
:: MODIFIES: INSTALL_STATUS
:: RETURNS: Provided error code
::===================================================================
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

::===================================================================
:: FUNCTION: InitializeEnvironment
:: Verifies system requirements and setup
:: RETURNS: 0=Success, 1=MissingReqs, 2=NetworkError, 4=DiskSpace
::===================================================================
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

::===================================================================
:: FUNCTION: LocateGame
:: Finds and validates game installation
:: MODIFIES: FOUND_PATH
:: RETURNS: 0=Success, 13=GameNotFound
::===================================================================
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
    :RetryPathInput
    set "USER_PATH="
    set /p "USER_PATH=Path: "
    
    if not defined USER_PATH (
        call :Log "DEBUG: No path entered"
        call :ColorEcho RED "No path entered."
        goto :RetryPathInput
    )
    
    :: Enhanced path sanitization
    set "FOUND_PATH=!USER_PATH:"=!"
    set "FOUND_PATH=!FOUND_PATH:&=!"
    set "FOUND_PATH=!FOUND_PATH:'=!"
    set "FOUND_PATH=!FOUND_PATH: = !"
    set "FOUND_PATH=!FOUND_PATH:\\=\!"
    
    :: Remove trailing slash/backslash
    if defined FOUND_PATH (
        :trimloop
        if "!FOUND_PATH:~-1!"=="\" set "FOUND_PATH=!FOUND_PATH:~0,-1!" & goto trimloop
        if "!FOUND_PATH:~-1!"=="/" set "FOUND_PATH=!FOUND_PATH:~0,-1!" & goto trimloop
    )
    
    call :Log "DEBUG: Sanitized path: '!FOUND_PATH!'"
    
    :: Validate path format
    echo !FOUND_PATH! | findstr /r /c:"^[A-Za-z]:\\[^/:\*\\?<>|\"]*$" >nul
    if !errorlevel! neq 0 (
        call :ColorEcho RED "Invalid path format. Path must be in format: C:\Folder\Subfolder"
        call :Log "Invalid path format: '!FOUND_PATH!'"
        goto :RetryPathInput
    )

:ValidateAndSet
    :: Enhanced path validation
    call :Log "DEBUG: Final validation path: '!FOUND_PATH!'"
    
    if not exist "!FOUND_PATH!\Lethal Company.exe" (
        call :ColorEcho RED "Lethal Company.exe not found at:"
        call :ColorEcho RED "!FOUND_PATH!"
        call :Log "DEBUG: Game executable not found at: '!FOUND_PATH!\Lethal Company.exe'"
        goto :RetryPathInput
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
    
::===================================================================
:: FUNCTION: CreateBackup
:: Creates backup of existing BepInEx installation
:: MODIFIES: BACKUP_DIR
:: RETURNS: 0=Success, 5=BackupError
::===================================================================
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

::===================================================================
:: FUNCTION: RestoreBackup
:: Restores BepInEx from backup
:: USES: BACKUP_DIR, FOUND_PATH
:: RETURNS: 0=Success, 3=NotFound, 8=RestoreError
::===================================================================
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

::===================================================================
:: FUNCTION: WriteVersionInfo
:: Updates mod version manifest
:: PARAMS: %1=Author, %2=ModName, %3=Version
:: RETURNS: 0=Success, 6=ConfigError, 8=WriteError
::===================================================================
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

::===================================================================
:: FUNCTION: DownloadFile
:: Downloads file from URL with error handling
:: PARAMS: %1=URL, %2=Output path
:: RETURNS: 0=Success, 2=Download failure
::===================================================================
:DownloadFile
    setlocal EnableDelayedExpansion
    set "URL=%~1"
    set "OUTPUT=%~2"

    powershell -Command "$ErrorActionPreference = 'Stop';" ^
        "try { " ^
            "$ProgressPreference = 'SilentlyContinue';" ^
            "$webClient = New-Object System.Net.WebClient;" ^
            "$webClient.Headers.Add('User-Agent', 'LCPlusInstaller/%VERSION%');" ^
            "$webClient.DownloadFile('%URL%', '%OUTPUT%') " ^
        "} catch { " ^
            "Write-Host $_.Exception.Message 2>&1 | Out-Null; " ^
            "exit 1 " ^
        "}"
    
    if !errorlevel! neq 0 (
        endlocal
        exit /b 2
    )
    
    :: Verify file exists and is not empty
    if not exist "!OUTPUT!" (
        endlocal
        exit /b 2
    )
    
    for %%A in ("!OUTPUT!") do (
        if %%~zA LEQ 0 (
            del "!OUTPUT!" 2>nul
            endlocal
            exit /b 2
        )
    )
    
    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: CALL_THUNDERSTORE_API
:: Fetches mod info from Thunderstore API
:: PARAMS: %1=Author, %2=ModName, %3=OutputFile
:: USES: TEMP_DIR, LOG_DIR
:: RETURNS: 0=Success, 2=Network error, 10=Invalid response
::===================================================================
:CALL_THUNDERSTORE_API
    setlocal EnableDelayedExpansion
    set "MOD_AUTHOR=%~1"
    set "MOD_NAME=%~2"
    set "OUTPUT_FILE=%~3"
    
    :: Ensure required directories exist
    if not exist "!LOG_DIR!" (
        mkdir "!LOG_DIR!" 2>nul || (
            call :HandleError "Failed to create log directory" 3
            endlocal
            exit /b 3
        )
    )
    
    set "API_LOG=!LOG_DIR!\!MOD_NAME!_api.log"
    
    :: Ensure parent directory of OUTPUT_FILE exists
    for %%F in ("!OUTPUT_FILE!") do (
        set "OUTPUT_DIR=%%~dpF"
        if not exist "!OUTPUT_DIR!" (
            mkdir "!OUTPUT_DIR!" 2>nul || (
                call :HandleError "Failed to create output directory" 3
                endlocal
                exit /b 3
            )
        )
    )

    :: Setup API endpoint
    set "API_URL=https://thunderstore.io/api/experimental/package/!MOD_AUTHOR!/!MOD_NAME!/"

    :: Log the URL before making the request
    set "LOG_MESSAGE=Fetching mod info from: !API_URL!"
    call :Log "!LOG_MESSAGE!"

    :: Create a temporary response file
    set "TEMP_RESPONSE=!TEMP_DIR!\!MOD_NAME!_response.json"

    :: Make API request with enhanced error handling
    powershell -Command ^
        "$ErrorActionPreference = 'Stop';" ^
        "$ProgressPreference = 'SilentlyContinue';" ^
        "try {" ^
            "$response = Invoke-RestMethod -Uri '!API_URL!' -Method Get;" ^
            "if ($null -eq $response.latest.version_number -or $null -eq $response.latest.download_url) {" ^
                "throw 'Invalid API response structure'" ^
            "}" ^
            "$response | ConvertTo-Json | Set-Content -Path '!TEMP_RESPONSE!';" ^
            "'VERSION=' + $response.latest.version_number | Set-Content -Path '!OUTPUT_FILE!';" ^
            "'URL=' + $response.latest.download_url | Add-Content -Path '!OUTPUT_FILE!';" ^
        "} catch {" ^
            "$_.Exception.Message | Out-File '!API_LOG!';" ^
            "exit $(if ($_.Exception.Message -match 'Invalid API') { 10 } else { 2 })" ^
        "}"

    if !errorlevel! equ 2 (
        call :HandleError "Network error fetching !MOD_NAME! info" 2 "!API_LOG!"
        endlocal
        exit /b 2
    ) else if !errorlevel! equ 10 (
        call :HandleError "Invalid API response for !MOD_NAME!" 10 "!API_LOG!"
        endlocal
        exit /b 10
    )

    :: Validate output file exists and has content
    if not exist "!OUTPUT_FILE!" (
        call :HandleError "API response file not created for !MOD_NAME!" 10
        endlocal
        exit /b 10
    )

    :: Verify required data is present
    findstr /B "VERSION=" "!OUTPUT_FILE!" >nul || (
        call :HandleError "Missing version info in API response for !MOD_NAME!" 10
        type "!API_LOG!" >> "!LOG_FILE!"
        type "!TEMP_RESPONSE!" >> "!LOG_FILE!"
        endlocal
        exit /b 10
    )
    findstr /B "URL=" "!OUTPUT_FILE!" >nul || (
        call :HandleError "Missing URL in API response for !MOD_NAME!" 10
        type "!API_LOG!" >> "!LOG_FILE!"
        type "!TEMP_RESPONSE!" >> "!LOG_FILE!"
        endlocal
        exit /b 10
    )

    :: Clean up temporary response file
    if exist "!TEMP_RESPONSE!" del /f /q "!TEMP_RESPONSE!" 2>nul

    endlocal
    exit /b 0
    
::===================================================================
:: FUNCTION: DownloadMod
:: Downloads and validates specific mod package
:: PARAMS: %1=URL, %2=OutputPath, %3=ModName
:: USES: LOG_DIR
:: RETURNS: 0=Success, 1=NotFound, 2=DownloadError
::===================================================================
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

::===================================================================
:: FUNCTION: INSTALL_BEPINEX_PACK
:: Installs BepInEx mod loader and verifies installation
:: USES: TEMP_DIR, EXTRACT_DIR, FOUND_PATH
:: RETURNS: 0=Success, 2-9=Various installation errors
::===================================================================
:INSTALL_BEPINEX_PACK
    setlocal EnableDelayedExpansion
    call :Log "Starting BepInExPack installation..."
    call :ColorEcho BLUE "► Installing BepInExPack..."

    :: Use centralized API helper to get version info
    set "API_OUTPUT=%TEMP_DIR%\BepInExPack_api.txt"
    call :CALL_THUNDERSTORE_API "BepInEx" "BepInExPack" "!API_OUTPUT!"
    if !errorlevel! neq 0 (
        endlocal
        exit /b !errorlevel!
    )

    :: Parse version and URL
    for /f "tokens=2 delims==" %%a in ('type "!API_OUTPUT!" ^| findstr /B "VERSION="') do set "VERSION=%%a"
    for /f "tokens=2 delims==" %%a in ('type "!API_OUTPUT!" ^| findstr /B "URL="') do set "DOWNLOAD_URL=%%a"
    
    :: Trim whitespace from parsed values
    set "VERSION=!VERSION: =!"
    set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

    :: Setup paths
    set "ZIP_FILE=!TEMP_DIR!\BepInExPack_v!VERSION!.zip"
    set "EXTRACT_ROOT=!EXTRACT_DIR!\BepInEx"
    
    :: Download BepInExPack
    call :Log "Downloading BepInExPack from: !DOWNLOAD_URL!"
    call :ColorEcho WHITE "* Downloading BepInExPack..."
    call :DownloadFile "!DOWNLOAD_URL!" "!ZIP_FILE!" 2>"!LOG_DIR!\BepInExPack_download.log"

    if !errorlevel! neq 0 (
        call :HandleError "Failed to download BepInExPack" 2 "!LOG_DIR!\BepInExPack_download.log"
        endlocal
        exit /b 2
    )

    :: Extract BepInExPack
    call :Log "Extracting BepInExPack..." "console"
    if exist "!EXTRACT_ROOT!" rd /s /q "!EXTRACT_ROOT!" >nul 2>&1
    call :ExtractFiles "!ZIP_FILE!" "!EXTRACT_ROOT!" "BepInExPack"
    if !errorlevel! neq 0 (
        call :HandleError "Failed to extract BepInExPack" 9 "!LOG_DIR!\BepInExPack_extract.log"
        endlocal
        exit /b 9
    )

    :: Log the extracted contents for debugging
    call :Log "Listing extracted contents:"
    dir /s /b "!EXTRACT_ROOT!" >> "!LOG_FILE!"

    :: Verify expected folder structure
    set "BEPINPACK_ROOT=!EXTRACT_ROOT!\BepInExPack"
    
    if not exist "!BEPINPACK_ROOT!\doorstop_config.ini" (
        call :HandleError "doorstop_config.ini not found in BepInExPack folder" 9
        endlocal
        exit /b 9
    )

    if not exist "!BEPINPACK_ROOT!\winhttp.dll" (
        call :HandleError "winhttp.dll not found in BepInExPack folder" 9
        endlocal
        exit /b 9
    )

    if not exist "!BEPINPACK_ROOT!\BepInEx" (
        call :HandleError "BepInEx folder not found in BepInExPack folder" 9
        endlocal
        exit /b 9
    )

    :: Ensure target directories exist
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx"
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\core"
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\config"
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\plugins"
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\patchers"

    :: Copy root files (doorstop and winhttp)
    call :Log "Copying BepInEx root files..."
    call :ColorEcho WHITE "* Installing BepInEx root files..."
    for %%F in (doorstop_config.ini winhttp.dll) do (
        copy /Y "!BEPINPACK_ROOT!\%%F" "!FOUND_PATH!\%%F" >nul || (
            call :HandleError "Failed to copy %%F to root folder" 8
            endlocal
            exit /b 8
        )
    )

    :: Copy BepInEx folder contents
    call :Log "Copying BepInEx folder..."
    robocopy "!BEPINPACK_ROOT!\BepInEx" "!FOUND_PATH!\BepInEx" ^
        /E /COPYALL /R:0 /W:0 /NP ^
        /LOG+:"!LOG_DIR!\BepInExPack_install.log" >nul
    if !errorlevel! GEQ 8 (
        call :HandleError "Failed to copy BepInEx folder" 8 ^
            "!LOG_DIR!\BepInExPack_install.log"
        endlocal
        exit /b 8
    )

    :: Verify critical files
    set "MISSING_FILES="
    set "MISSING_COUNT=0"
    
    for %%F in (
        "!FOUND_PATH!\winhttp.dll"
        "!FOUND_PATH!\doorstop_config.ini"
        "!FOUND_PATH!\BepInEx\core\BepInEx.dll"
        "!FOUND_PATH!\BepInEx\core\BepInEx.Preloader.dll"
    ) do (
        if not exist "%%~F" (
            set "MISSING_FILES=!MISSING_FILES! %%~nxF"
            set /a "MISSING_COUNT+=1"
        )
    )

    if defined MISSING_FILES (
        call :HandleError "Missing !MISSING_COUNT! critical BepInEx files:!MISSING_FILES!" 6
        endlocal
        exit /b 6
    )

    call :Log "BepInExPack installation completed successfully"
    call :ColorEcho GREEN "✓ BepInExPack installed successfully"
    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: DownloadModlist
:: Downloads and parses mod configuration
:: MODIFIES: MOD_LIST
:: RETURNS: 0=Success, 2=DownloadError, 14=NoValidMods
::===================================================================
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

::===================================================================
:: FUNCTION: InitializeLogging
:: Sets up logging system and initial log entry
:: USES: LOG_FILE
::===================================================================
:InitializeLogging
    echo [%date% %time%] Lethal Company Plus installation started > "%LOG_FILE%"
    echo [%date% %time%] Initializing installer... >> "%LOG_FILE%"
    exit /b 0

::===================================================================
:: FUNCTION: DownloadModlist
:: Downloads and parses mod configuration
:: MODIFIES: MOD_LIST
:: RETURNS: 0=Success, 2=DownloadError, 14=NoValidMods
::===================================================================
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