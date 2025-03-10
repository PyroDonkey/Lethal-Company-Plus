@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: Add early console encoding configuration
powershell -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" >nul

:: Initialization Entry Point
call :InitializeConfig
goto :START_INSTALLATION

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

:: Temporary working variables
set "CONFIRMATION_FILE=%TEMP_DIR%\install_confirmed.flag"

:: =====================================================================
:: FUNCTION: INITIALIZECONFIG
:: PURPOSE: Initializes all configuration variables and error messages
:: PARAMS: None
:: MODIFIES: GAME_NAME, STEAM_APPID, MODLIST_URL, TEMP_DIR, VERSION
:: RETURNS: 0 (Always succeeds)
:: =====================================================================
:InitializeConfig
    :: Game Information
    set "GAME_NAME=Lethal Company"
    set "STEAM_APPID=1966720"
    
    :: Core Components
    set "BEPINEX_AUTHOR=BepInEx"
    set "BEPINEX_NAME=BepInExPack"
    
    :: URL Configuration
    set "MODLIST_URL=https://raw.githubusercontent.com/PyroDonkey/Lethal-Company-Plus/main/Modlist/modlist.ini"

    :: Path Configuration
    set "TEMP_DIR=%TEMP%\LCPlusInstall"
    set "LOG_DIR=%TEMP_DIR%\logs"
    set "LOG_FILE=%LOG_DIR%\debug.log" 
    set "EXTRACT_DIR=%TEMP_DIR%\extracted"
    set "CONFIRMATION_FILE=%TEMP_DIR%\install_confirmed.flag"

    :: Version Information
    set "VERSION=1.10.0"
    set "LAST_MODIFIED=2025-02-23"

    :: Error Message Definitions
    set "ERROR_MSG_1=General/unexpected error"
    set "ERROR_MSG_2=Network communication failure"
    set "ERROR_MSG_3=File/directory not found"
    set "ERROR_MSG_4=Insufficient disk space"
    set "ERROR_MSG_5=Backup/restore operation failure"
    set "ERROR_MSG_6=BepInEx configuration error"
    set "ERROR_MSG_7=Registry access failure"
    set "ERROR_MSG_8=File operation failure (copy/delete)"
    set "ERROR_MSG_9=Archive extraction failure"
    set "ERROR_MSG_10=Invalid API response"
    set "ERROR_MSG_11=User input validation failed"
    set "ERROR_MSG_12=Permission denied"
    set "ERROR_MSG_13=Invalid game installation path"
    set "ERROR_MSG_14=Mod installation failure"
    set "ERROR_MSG_15=Uninstall operation failed"

    :: Load error code mappings
    call :DefineErrorCodes

    :: Installation State Tracking
    set "INSTALL_STATUS=0"
    set "FOUND_PATH="
    set "VERSION_FILE="
    set "BACKUP_DIR="
exit /b 0

:: =====================================================================
:: FUNCTION: DEFINEERRORCODES
:: PURPOSE: Maps error messages to error codes
:: PARAMS: None
:: MODIFIES: ERROR_CODE_1 to ERROR_CODE_15
:: RETURNS: 0 (Always succeeds)
:: =====================================================================
:DefineErrorCodes
    set "ERROR_CODE_1=%ERROR_MSG_1%"
    set "ERROR_CODE_2=%ERROR_MSG_2%"
    set "ERROR_CODE_3=%ERROR_MSG_3%"
    set "ERROR_CODE_4=%ERROR_MSG_4%"
    set "ERROR_CODE_5=%ERROR_MSG_5%"
    set "ERROR_CODE_6=%ERROR_MSG_6%"
    set "ERROR_CODE_7=%ERROR_MSG_7%"
    set "ERROR_CODE_8=%ERROR_MSG_8%"
    set "ERROR_CODE_9=%ERROR_MSG_9%"
    set "ERROR_CODE_10=%ERROR_MSG_10%"
    set "ERROR_CODE_11=%ERROR_MSG_11%"
    set "ERROR_CODE_12=%ERROR_MSG_12%"
    set "ERROR_CODE_13=%ERROR_MSG_13%"
    set "ERROR_CODE_14=%ERROR_MSG_14%"
    set "ERROR_CODE_15=%ERROR_MSG_15%"
exit /b 0

:: =====================================================================
:: FUNCTION: CHECK_AND_REQUEST_ELEVATION
:: PURPOSE: Requests and verifies admin privileges
:: PARAMS: None
:: MODIFIES: INSTALL_STATUS
:: RETURNS: 0=Success, 12=ElevationFailed
:: =====================================================================
:CHECK_AND_REQUEST_ELEVATION
    WHOAMI /GROUPS | findstr /b /c:"Mandatory Label\High Mandatory Level" >nul 2>&1
    if %errorlevel% equ 0 (
        goto :START_INSTALLATION
    )

    echo Requesting administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "& {Start-Process '%~f0' -Verb RunAs -ErrorAction Stop; exit $LASTEXITCODE}"

    if %errorlevel% neq 0 (
        call :HandleError 12
        goto :CLEANUP
    )

:: =====================================================================
:: FUNCTION: START_INSTALLATION
:: PURPOSE: Main installation sequence controller
:: PARAMS: None
:: MODIFIES: INSTALL_STATUS
:: RETURNS: Proceeds to CLEANUP with appropriate INSTALL_STATUS
::===================================================================
:START_INSTALLATION
    :: Create working directories first
    call :CREATE_DIRECTORY "%TEMP_DIR%" || exit /b 3
    call :CREATE_DIRECTORY "%LOG_DIR%" || exit /b 3
    call :CREATE_DIRECTORY "%EXTRACT_DIR%" || exit /b 3
    
    :: Ensure UTF-8 output capabilities
    powershell -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" >nul
    powershell -Command "$OutputEncoding = [System.Text.Encoding]::UTF8" >nul
    
    :: Update ANSI initialization to use proper escape sequence
    for /F %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
    set "GREEN=!ESC![92m"
    set "YELLOW=!ESC![93m"
    set "RED=!ESC![91m"
    set "BLUE=!ESC![94m"
    set "CYAN=!ESC![96m"
    set "WHITE=!ESC![97m"
    set "RESET=!ESC![0m"

    :: Initialize logging after directories are created
    call :InitializeLogging

    :: Core installation sequence
    call :InitializeEnvironment || (
        call :HandleError 1
        goto :CLEANUP
    )

    call :LocateGame || (
        call :HandleError 13
        goto :CLEANUP
    )

    call :DownloadModlist || (
        call :HandleError 10
        goto :CLEANUP
    )

    call :SHOW_MOD_LIST_AND_CONFIRM || (
        call :Log "Installation cancelled by user" "console"
        call :ColorEcho YELLOW "Installation cancelled"
        set INSTALL_STATUS=11
        goto :CLEANUP
    )

    call :INSTALL_BEPINEX_PACK || (
        call :HandleError 6
        goto :CLEANUP
    )

    call :INSTALL_ALL_MODS || (
        call :HandleError 14
        goto :CLEANUP
    )

    goto :CLEANUP

::===================================================================
:: FUNCTION: INSTALL_ALL_MODS
:: PURPOSE: Processes and installs all configured mods
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

:: =====================================================================
:: FUNCTION: GetModInfo
:: PURPOSE: Retrieves mod version and download URL from Thunderstore API
:: PARAMS: %1=Author, %2=ModName
:: RETURNS: Sets MOD_VERSION and DOWNLOAD_URL, or errorlevel on failure
:: =====================================================================
:GetModInfo
    setlocal EnableDelayedExpansion
    set "MOD_AUTHOR=%~1"
    set "MOD_NAME=%~2"

    :: Set up API output file path
    set "API_OUTPUT=%TEMP_DIR%\!MOD_NAME!_api.txt"

    :: Call API helper to get version info
    call :CALL_THUNDERSTORE_API "!MOD_AUTHOR!" "!MOD_NAME!" "!API_OUTPUT!"
    if !errorlevel! neq 0 (
        endlocal
        exit /b !errorlevel!
    )

    :: Parse version and URL from API response
    for /f "tokens=2 delims==" %%a in ('findstr /B "VERSION" "!API_OUTPUT!"') do set "MOD_VERSION=%%a"
    for /f "tokens=2 delims==" %%a in ('findstr /B "URL" "!API_OUTPUT!"') do set "DOWNLOAD_URL=%%a"

    :: Remove any spaces from parsed values
    set "MOD_VERSION=!MOD_VERSION: =!"
    set "DOWNLOAD_URL=!DOWNLOAD_URL: =!"

    :: Return values to calling function
    endlocal & (
        set "MOD_VERSION=%MOD_VERSION%"
        set "DOWNLOAD_URL=%DOWNLOAD_URL%"
    )
    exit /b 0

::===================================================================
:: FUNCTION: DOWNLOADANDEXTRACTMOD
:: PURPOSE: Downloads and extracts a specific mod package
:: PARAMS: %1=Author, %2=ModName, %3=Version, %4=DownloadURL
:: RETURNS: 0=Success, 2=DownloadError, 3=DirectoryError, 9=ExtractError
::===================================================================
:DownloadAndExtractMod
    setlocal EnableDelayedExpansion
    set "MOD_AUTHOR=%~1"
    set "MOD_NAME=%~2"
    set "MOD_VERSION=%~3"
    set "DOWNLOAD_URL=%~4"

    :: Setup file paths
    set "ZIP_FILE=!TEMP_DIR!\!MOD_NAME!_v!MOD_VERSION!.zip"
    set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"

    :: Download mod
    call :ColorEcho WHITE "* Downloading !MOD_NAME!..."
    call :DownloadFile "!DOWNLOAD_URL!" "!ZIP_FILE!" 2>"!LOG_DIR!\!MOD_NAME!_download.log"
    if !errorlevel! neq 0 (
        call :HandleError 2 "!LOG_DIR!\!MOD_NAME!_download.log" "MOD_NAME DOWNLOAD_URL ZIP_FILE"
        endlocal
        exit /b 2
    )

    :: Clean extract directory if it exists
    if exist "!MOD_EXTRACT_DIR!" rd /s /q "!MOD_EXTRACT_DIR!"

    :: Create fresh extract directory
    call :CREATE_DIRECTORY "!MOD_EXTRACT_DIR!" || (
        endlocal
        call :HandleError 3 "" "MOD_EXTRACT_DIR"
    )

    :: Extract mod
    call :ExtractFiles "!ZIP_FILE!" "!MOD_EXTRACT_DIR!" "!MOD_NAME!"
    if !errorlevel! neq 0 (
        call :HandleError 9 "!LOG_DIR!\BepInExPack_extract.log" "ZIP_FILE EXTRACT_ROOT"
        endlocal
        exit /b 9
    )

    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: INSTALLSINGLEMOD
:: PURPOSE: Handles installation of individual mod
:: PARAMS: %1=Author, %2=ModName, %3=Index
:: RETURNS: 0=Success, Various installation error codes
::===================================================================
:InstallSingleMod
    setlocal EnableDelayedExpansion
    set "MOD_AUTHOR=%~1"
    set "MOD_NAME=%~2"
    set "MOD_INDEX=%~3"
    
    :: Create padded index for sorted load order
    set "MOD_INDEX_PADDED=0!MOD_INDEX!"
    set "MOD_INDEX_PADDED=!MOD_INDEX_PADDED:~-2!"

    :: Get mod version and download URL
    call :GetModInfo "!MOD_AUTHOR!" "!MOD_NAME!"
    if !errorlevel! neq 0 (
        endlocal
        exit /b !errorlevel!
    )

    :: Setup paths
    set "INSTALL_DIR=!FOUND_PATH!\BepInEx\plugins\!MOD_INDEX_PADDED!_!MOD_NAME!"
    set "MOD_EXTRACT_DIR=!EXTRACT_DIR!\!MOD_NAME!"

    :: Download and extract the mod using helper
    call :DownloadAndExtractMod "!MOD_AUTHOR!" "!MOD_NAME!" "!MOD_VERSION!" "!DOWNLOAD_URL!"
    if !errorlevel! neq 0 (
        endlocal
        exit /b !errorlevel!
    )

    :: Verify extraction directory exists
    if not exist "!MOD_EXTRACT_DIR!" (
        call :HandleError 3 "" "MOD_EXTRACT_DIR"
        endlocal
        exit /b 3
    )

    :: Create mod's plugin directory
    call :CREATE_DIRECTORY "!INSTALL_DIR!" || (
        call :HandleError 8 "" "INSTALL_DIR"
        endlocal
        exit /b 8
    )

    :: Initialize counter
    set "FILES_COPIED=0"

    :: Determine source directory and process files
    set "SOURCE_BASE=!MOD_EXTRACT_DIR!"
    if exist "!MOD_EXTRACT_DIR!\BepInEx" (
        set "SOURCE_BASE=!MOD_EXTRACT_DIR!\BepInEx"
    )

    :: Process all files
    for /f "delims=" %%F in ('dir /b /s /a-d "!MOD_EXTRACT_DIR!"') do (
        :: Get just filename
        for %%A in ("%%F") do set "FILE_NAME=%%~nxA"
        
        :: Default destination is mod's plugin directory
        set "DEST_PATH=!INSTALL_DIR!\!FILE_NAME!"

        :: Check for patchers (case-insensitive)
        echo "%%F" | findstr /i "\\BepInEx\\Patchers\\" >nul
        if !errorlevel! equ 0 (
            set "PATCHERS_DIR=!FOUND_PATH!\BepInEx\Patchers"
            call :CREATE_DIRECTORY "!PATCHERS_DIR!" || (
                call :HandleError 8
                endlocal
                exit /b 8
            )
            set "DEST_PATH=!PATCHERS_DIR!\!FILE_NAME!"
            call :Log "Found patcher file: !FILE_NAME!"
        )

        :: Copy file
        call :CopyFile "%%F" "!DEST_PATH!" "!MOD_NAME!"
        if !errorlevel! equ 0 (
            set /a "FILES_COPIED+=1"
        ) else (
            endlocal
            exit /b 8
        )
    )

    :: Verify at least one file copied
    if !FILES_COPIED! equ 0 (
        call :HandleError 8 "" "MOD_NAME"
        endlocal
        exit /b 8
    )

    :: Record version (continues even if this fails)
    call :WriteVersionInfo "!MOD_AUTHOR!" "!MOD_NAME!" "!MOD_VERSION!"

    :: Clean up
    rd /s /q "!MOD_EXTRACT_DIR!" 2>nul

    call :ColorEcho GREEN "✓ Successfully installed !MOD_NAME! v!MOD_VERSION! ^(!FILES_COPIED! files^)"
    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: SHOW_MOD_LIST_AND_CONFIRM
:: PURPOSE: Displays mods and gets user confirmation
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
        endlocal
        call :HandleError 11
        goto :CONFIRM_LOOP
    )

:: =====================================================================
:: FUNCTION: UNINSTALL_MODS
:: PURPOSE: Handles the uninstallation of BepInEx, mods, and related files
:: PARAMS: None
:: MODIFIES: INSTALL_STATUS
:: RETURNS: 0=Success, 15=UninstallOperationFailed
:: =====================================================================
:UNINSTALL_MODS
    setlocal EnableDelayedExpansion
    call :Log "Starting uninstallation process..."
    
    :: Check if BepInEx exists
    if not exist "!FOUND_PATH!\BepInEx" (
        call :ColorEcho YELLOW "No BepInEx installation found. Nothing to uninstall."
        endlocal
        exit /b 0
    )

    :: Initialize backup tracking variables
    set "BACKUP_COUNT=0"
    set "LATEST_BACKUP="
    set "LATEST_DATE="
    
    :: Count and list available backups
    for /f "delims=" %%a in ('dir /b /ad /o-d "%TEMP%\LCPlusInstall\backup_*" 2^>nul') do (
        set /a "BACKUP_COUNT+=1"
        if not defined LATEST_BACKUP (
            set "LATEST_BACKUP=%TEMP%\LCPlusInstall\%%a"
            set "LATEST_DATE=%%a"
        )
    )

    :: If backups exist, show them and get user choice
    if !BACKUP_COUNT! gtr 0 (
        call :ColorEcho CYAN "Found !BACKUP_COUNT! backup^(s^) of BepInEx ^(including mods and configs^):"
        echo.
        
        set "INDEX=1"
        for /f "delims=" %%a in ('dir /b /ad /o-d "%TEMP%\LCPlusInstall\backup_*" 2^>nul') do (
            :: Extract date components from backup folder name
            set "BACKUP_NAME=%%a"
            set "YEAR=!BACKUP_NAME:~13,2!"
            set "MONTH=!BACKUP_NAME:~11,2!"
            set "DAY=!BACKUP_NAME:~7,2!"
            
            :: Convert month number to three-letter abbreviation
            set "MONTH_NAME="
            if "!MONTH!"=="01" set "MONTH_NAME=Jan"
            if "!MONTH!"=="02" set "MONTH_NAME=Feb"
            if "!MONTH!"=="03" set "MONTH_NAME=Mar"
            if "!MONTH!"=="04" set "MONTH_NAME=Apr"
            if "!MONTH!"=="05" set "MONTH_NAME=May"
            if "!MONTH!"=="06" set "MONTH_NAME=Jun"
            if "!MONTH!"=="07" set "MONTH_NAME=Jul"
            if "!MONTH!"=="08" set "MONTH_NAME=Aug"
            if "!MONTH!"=="09" set "MONTH_NAME=Sep"
            if "!MONTH!"=="10" set "MONTH_NAME=Oct"
            if "!MONTH!"=="11" set "MONTH_NAME=Nov"
            if "!MONTH!"=="12" set "MONTH_NAME=Dec"
            
            :: Remove leading zero from day if present
            if "!DAY:~0,1!"=="0" set "DAY=!DAY:~1!"
            
            call :ColorEcho WHITE "  !INDEX!. Backup from !MONTH_NAME!-!DAY!-!YEAR!"
            set /a "INDEX+=1"
        )
        
        echo.
        call :ColorEcho YELLOW "Would you like to:"
        call :ColorEcho WHITE "  1. Remove mods and keep all backups"
        call :ColorEcho WHITE "  2. Remove mods and delete all backups"
        call :ColorEcho WHITE "  3. Cancel uninstallation"
        
        :BACKUP_CHOICE_LOOP
        set /p "BACKUP_CHOICE=Choose an option (1-3): "
        
        if "!BACKUP_CHOICE!"=="1" (
            call :ColorEcho WHITE "Keeping all backup folders"
        ) else if "!BACKUP_CHOICE!"=="2" (
            call :ColorEcho WHITE "* Removing all backup folders..."
            for /f "delims=" %%a in ('dir /b /ad "%TEMP%\LCPlusInstall\backup_*" 2^>nul') do (
                rd /s /q "%TEMP%\LCPlusInstall\%%a" 2>nul
                if !errorlevel! neq 0 (
                    call :ColorEcho YELLOW "Warning: Could not remove backup folder: %%a"
                )
            )
        ) else if "!BACKUP_CHOICE!"=="3" (
            call :ColorEcho WHITE "Uninstallation cancelled."
            endlocal
            exit /b 0
        ) else (
            call :ColorEcho RED "Invalid choice. Please enter 1, 2, or 3."
            goto :BACKUP_CHOICE_LOOP
        )
    )

    :: Mod Removal Section
    call :ColorEcho BLUE "► Starting uninstallation..."
    call :Log "Beginning mod removal process..."

    :: Remove BepInEx folder
    call :ColorEcho WHITE "* Removing BepInEx folder..."
    rd /s /q "!FOUND_PATH!\BepInEx" 2>nul
    if !errorlevel! neq 0 (
        endlocal
        call :HandleError 8 "" "FOUND_PATH\BepInEx"
    )

    :: Remove Cache folder
    call :ColorEcho WHITE "* Removing Cache folder..."
    if exist "!FOUND_PATH!\Cache" (
        rd /s /q "!FOUND_PATH!\Cache" 2>nul
        if !errorlevel! neq 0 (
            endlocal
            call :HandleError 8 "" "FOUND_PATH\Cache"
        )
    )

    :: Remove doorstop files
    call :ColorEcho WHITE "* Removing doorstop files..."
    if exist "!FOUND_PATH!\doorstop_config.ini" (
        del /f /q "!FOUND_PATH!\doorstop_config.ini" || (
            endlocal
            call :HandleError 8 "" "FOUND_PATH\doorstop_config.ini"
        )
    )
    if exist "!FOUND_PATH!\winhttp.dll" (
        del /f /q "!FOUND_PATH!\winhttp.dll" || (
            endlocal
            call :HandleError 8 "" "FOUND_PATH\winhttp.dll"
        )
    )

    :: Verification Section
    call :Log "Verifying complete removal of all components..."
    
    :: Check for any remaining mod-related files
    set "REMAINING_PATHS="
    if exist "!FOUND_PATH!\BepInEx" set "REMAINING_PATHS=!REMAINING_PATHS! BepInEx"
    if exist "!FOUND_PATH!\Cache" set "REMAINING_PATHS=!REMAINING_PATHS! Cache"
    if exist "!FOUND_PATH!\doorstop_config.ini" set "REMAINING_PATHS=!REMAINING_PATHS! doorstop_config.ini"
    if exist "!FOUND_PATH!\winhttp.dll" set "REMAINING_PATHS=!REMAINING_PATHS! winhttp.dll"

    if defined REMAINING_PATHS (
        endlocal
        call :HandleError 8 "" "FOUND_PATH REMAINING_PATHS"
    )

    :: Completion Section
    call :Log "Uninstallation completed successfully" "console"
    call :ColorEcho GREEN "✓ Mods successfully uninstalled"
    call :ColorEcho WHITE "The game has been restored to vanilla state."
    
    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: CREATE_DIRECTORY
:: PURPOSE: Creates directory with standardized error handling
:: PARAMS: %1=DirectoryPath
:: RETURNS: 0=Success, exits with error code 3 on failure
::===================================================================
:CREATE_DIRECTORY
    setlocal EnableDelayedExpansion
    set "DIR_PATH=%~1"
    if not exist "!DIR_PATH!" (
        mkdir "!DIR_PATH!" 2>nul || (
            call :HandleError 3 "" "DIR_PATH"
            endlocal
        )
    )
    endlocal
    exit /b 0

:: =====================================================================
:: FUNCTION: Log
:: PURPOSE: Writes messages to log file and optionally console
:: PARAMS: %1=Message, %2=ConsoleFlag
:: USES: LOG_FILE
:: RETURNS: 0=Success
:: =====================================================================
:Log
    setlocal EnableDelayedExpansion
    set "MESSAGE=%~1"
    set "CONSOLE=%~2"
    echo [%date% %time%] !MESSAGE! >> "!LOG_FILE!"
    if "!CONSOLE!"=="console" echo !MESSAGE!
    endlocal
    exit /b 0

:: =====================================================================
:: FUNCTION: ColorEcho
:: PURPOSE: Outputs colored text when ANSI colors are supported
:: PARAMS: %1=Color, %2=Message
:: MODIFIES: None
:: RETURNS: 0=Success
:: =====================================================================
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

:: =====================================================================
:: FUNCTION: HandleError
:: PURPOSE: Processes and logs error conditions, retrieves error description
:: PARAMS: %1=Code, %2=OptionalLogFile, %3=OptionalContextVars
:: MODIFIES: INSTALL_STATUS
:: RETURNS: Provided error code
:: =====================================================================
:HandleError
    setlocal DisableDelayedExpansion
    set "ERROR_CATEGORY_CODE=%~1"
    set "ERROR_LOG=%~2"
    set "VAR_LIST=%~3"

    :: Robust error message lookup with delayed expansion protection
    set "ERROR_DESCRIPTION=Unknown error (code !ERROR_CATEGORY_CODE!)"
    for /f "tokens=1,* delims==" %%A in ('set ERROR_CODE_!ERROR_CATEGORY_CODE! 2^>nul') do (
        set "ERROR_DESCRIPTION=%%B"
    )

    :: Now enable delayed expansion for message processing
    setlocal EnableDelayedExpansion
    :: Log error with proper escaping and improved formatting
    call :Log "ERROR [!ERROR_CATEGORY_CODE!]:  !ERROR_DESCRIPTION!" "console"
    call :ColorEcho RED "X ERROR [!ERROR_CATEGORY_CODE!]:  !ERROR_DESCRIPTION!"

    :: Context variable handling
    if defined VAR_LIST (
        call :Log "Error context variables:" "console"
        for %%V in (!VAR_LIST!) do (
            if defined %%V (
                call :Log "  %%V=!%%V!" "console"
            ) else (
                call :Log "  %%V=<undefined>" "console"
            )
        )
    )

    :: Additional error logs with timestamped entries
    if defined ERROR_LOG (
        if exist "!ERROR_LOG!" (
            call :Log "Additional error details from !ERROR_LOG!:" "console"
            call :Log "----------------------------------------" "console"
            for /f "tokens=*" %%x in ('type "!ERROR_LOG!"') do (
                call :Log "%%x" "console"
            )
            call :Log "----------------------------------------" "console"
        )
    )

    :: Standard troubleshooting steps
    call :Log "Troubleshooting steps:" "console"
    call :Log "1. Verify internet connection" "console"
    call :Log "2. Check antivirus/firewall settings" "console"
    call :Log "3. Ensure sufficient disk space" "console"
    call :Log "4. Retry with administrator privileges" "console"

    :: Single endlocal for cleaner scope exit
    endlocal & endlocal & (
        set "INSTALL_STATUS=%ERROR_CATEGORY_CODE%"
        exit /b %ERROR_CATEGORY_CODE%
    )

:: =====================================================================
:: FUNCTION: InitializeEnvironment
:: PURPOSE: Verifies system requirements and setup
:: PARAMS: None
:: MODIFIES: None
:: RETURNS: 0=Success, 1=MissingReqs, 2=NetworkError, 4=DiskSpace
:: =====================================================================
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
        call :HandleError 1 "" "OS PROCESSOR_ARCHITECTURE"
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
        call :HandleError 2
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
        call :HandleError 4
        endlocal
        exit /b 4
    )

    call :Log "Environment check completed successfully"
    endlocal
    exit /b 0

:: =====================================================================
:: FUNCTION: LocateGame  
:: PURPOSE: Finds and validates game installation
:: PARAMS: None
:: MODIFIES: FOUND_PATH
:: RETURNS: 0=Success, 13=GameNotFound
:: =====================================================================
:LocateGame
    setlocal EnableDelayedExpansion
    set "FOUND_PATH="
    
    call :Log "Starting game location detection..."
    call :ColorEcho BLUE "► Searching for !GAME_NAME! installation..."
    echo.

    :: Steam AppID-based check
    call :Log "Checking Steam AppID (!STEAM_APPID!) locations..."
    reg query "HKCU\Software\Valve\Steam" /v SteamPath >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul') do (
            set "STEAM_PATH=%%C"
            if not defined STEAM_PATH (
                call :Log "WARNING: SteamPath registry value empty"
                goto :SteamCheckEnd
            )
            call :Log "Found Steam installation at: !STEAM_PATH!"
            
            :: Check libraryfolders.vdf
            set "LIBRARY_FILE=!STEAM_PATH!\steamapps\libraryfolders.vdf"
            if exist "!LIBRARY_FILE!" (
                call :Log "Parsing libraryfolders.vdf..."
                for /f "tokens=2 delims=^= " %%C in ('type "!LIBRARY_FILE!" ^| findstr /i /c:"\"path\""') do (
                    set "LIB_PATH=%%C"
                    set "LIB_PATH=!LIB_PATH:\"=!"
                    set "LIB_PATH=!LIB_PATH:"=!"
                    if not defined LIB_PATH (
                        call :Log "ERROR: Failed to parse library path"
                        call :HandleError 7 "" "LIBRARY_FILE"
                    )
                    call :Log "Checking library folder: !LIB_PATH!"
                    
                    :: App manifest handling
                    set "APP_MANIFEST=!LIB_PATH!\steamapps\appmanifest_!STEAM_APPID!.acf"
                    set "INSTALL_DIR="
                    
                    if exist "!APP_MANIFEST!" (
                        call :Log "Found appmanifest_!STEAM_APPID!.acf"
                        for /f "tokens=2 delims=^= " %%D in ('type "!APP_MANIFEST!" ^| findstr /c:"\"installdir\""') do (
                            set "INSTALL_DIR=%%D"
                            set "INSTALL_DIR=!INSTALL_DIR:\"=!"
                            set "INSTALL_DIR=!INSTALL_DIR:"=!"
                        )
                        if not defined INSTALL_DIR (
                            call :Log "ERROR: Failed to parse installdir from appmanifest"
                            call :HandleError 7 "" "APP_MANIFEST"
                        )
                        set "CHECK_PATH=!LIB_PATH!\steamapps\common\!INSTALL_DIR!"
                    ) else (
                        call :Log "No appmanifest found, using default path"
                        set "CHECK_PATH=!LIB_PATH!\steamapps\common\!GAME_NAME!"
                    )
                    
                    :: Final path validation
                    if exist "!CHECK_PATH!\Lethal Company.exe" (
                        set "FOUND_PATH=!CHECK_PATH!"
                        call :Log "Found game via AppID at: !FOUND_PATH!"
                        goto :ValidateAndSet
                    ) else (
                        call :Log "WARNING: Game not found at !CHECK_PATH!"
                    )
                )
            ) else (
                call :Log "WARNING: libraryfolders.vdf not found at !LIBRARY_FILE!"
            )
        )
    ) else (
        call :Log "Steam registry key not found in HKCU"
    )
    :SteamCheckEnd

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
                set "CHECK_PATH=%%C\steamapps\common\!GAME_NAME!"
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
    call :ColorEcho YELLOW "Unable to automatically locate !GAME_NAME!."
    echo.
    call :ColorEcho WHITE "Please enter the full path to your !GAME_NAME! installation"
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
        endlocal
        call :HandleError 13 "" "FOUND_PATH"
        goto :RetryPathInput
    )

::===================================================================
:: FUNCTION: VALIDATEANDSET
:: PURPOSE: Validates game installation path and critical files
:: PARAMS: None
:: USES: FOUND_PATH, MISSING_FILES, MISSING_COUNT
:: RETURNS: Continues execution on success, goes to RetryPathInput on failure 
::===================================================================
:ValidateAndSet
    
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
    call :ColorEcho GREEN "✓ !GAME_NAME! found at: '!FOUND_PATH!'"
    call :Log "Successfully located game at: '!FOUND_PATH!'"
    
    endlocal & set "FOUND_PATH=%FOUND_PATH%"
    exit /b 0
    
:: =====================================================================
:: FUNCTION: CREATEBACKUP
:: PURPOSE: Creates backup of existing BepInEx installation
:: PARAMS: None
:: MODIFIES: BACKUP_DIR
:: RETURNS: 0=Success, 5=BackupError
:: =====================================================================
:CreateBackup
    setlocal EnableDelayedExpansion
    call :ColorEcho BLUE "► Creating backup..."

    set "BACKUP_DIR=%TEMP_DIR%\backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
    set "BACKUP_DIR=%BACKUP_DIR: =0%"

    :: Check if BepInEx exists
    if exist "!FOUND_PATH!\BepInEx" (
        mkdir "!BACKUP_DIR!" 2>nul || (
            call :HandleError 5 "" "BACKUP_DIR"
        )

        :: Create backup with logging
        robocopy "!FOUND_PATH!\BepInEx" "!BACKUP_DIR!\BepInEx" /E /COPYALL /R:0 /W:0 /NP /LOG+:"!LOG_DIR!\backup.log" >nul
        if !errorlevel! GEQ 8 (
            call :HandleError 5 "!LOG_DIR!\backup.log"
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
    )

:: =====================================================================
:: FUNCTION: WRITEVERSIONINFO
:: PURPOSE: Updates mod version manifest
:: PARAMS: %1=Author, %2=ModName, %3=Version
:: MODIFIES: VERSION_FILE
:: RETURNS: 0=Success, 6=ConfigError, 8=WriteError
:: =====================================================================
:RestoreBackup
    setlocal EnableDelayedExpansion
    call :ColorEcho BLUE "► Restoring backup..."

    :: Verify backup exists
    if not exist "!BACKUP_DIR!\BepInEx" (
        endlocal
        call :HandleError 3 "" "BACKUP_DIR"
    )

    :: Remove current installation if it exists
    if exist "!FOUND_PATH!\BepInEx" (
        rd /s /q "!FOUND_PATH!\BepInEx"
        if !errorlevel! neq 0 (
            call :HandleError 8
        )
    )

    :: Restore BepInEx directory with robocopy
    robocopy "!BACKUP_DIR!\BepInEx" "!FOUND_PATH!\BepInEx" ^
        /E /COPYALL /R:0 /W:0 /NP ^
        /LOG+:"!LOG_DIR!\restore.log" >nul
    if !errorlevel! GEQ 8 (
        call :Log "ERROR: Failed to restore BepInEx directory"
        call :ColorEcho RED "ERROR: Installation failed"
        type "!LOG_DIR!\restore.log" >> "!LOG_FILE!"
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

:: =====================================================================
:: FUNCTION: WriteVersionInfo
:: PURPOSE: Updates mod version manifest
:: PARAMS: %1=Author, %2=ModName, %3=Version
:: MODIFIES: VERSION_FILE
:: RETURNS: 0=Success, 6=ConfigError, 8=WriteError
:: =====================================================================
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
        call :HandleError 6 "" "FOUND_PATH"
    )

    :: Create or update version file with author-name combination
    if not exist "!VERSION_FILE!" (
        echo !MOD_AUTHOR!-!MOD_NAME!=!MOD_VERSION!> "!VERSION_FILE!"
        if !errorlevel! neq 0 (
            call :HandleError 8 "" "VERSION_FILE"
        )
    )

    :: Create temporary file for version updates
    if exist "!TEMP_CFG!" del /f /q "!TEMP_CFG!"
    type nul > "!TEMP_CFG!" 2>nul
    if !errorlevel! neq 0 (
        call :HandleError 1
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
            call :HandleError 1
            if exist "!TEMP_CFG!" del /f /q "!TEMP_CFG!"
        )
    )

    call :Log "Updated version information for !MOD_AUTHOR!/!MOD_NAME! to v!MOD_VERSION!"
    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: DownloadFile
:: PURPOSE: Downloads file from URL with error handling and timeout
:: PARAMS: %1=URL, %2=Output path
:: MODIFIES: None
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
            "$job = Start-Job -ScriptBlock {" ^
                "param($url, $output)" ^
                "(New-Object System.Net.WebClient).DownloadFile($url, $output)" ^
            "} -ArgumentList '%URL%','%OUTPUT%';" ^
            "if (-not (Wait-Job $job -Timeout 30)) {" ^
                "Remove-Job -Force $job;" ^
                "throw 'Download timed out after 30 seconds'" ^
            "}" ^
            "Receive-Job $job" ^
        "} catch { " ^
            "$_.Exception.Message | Out-File '!LOG_DIR!\download.log'; " ^
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

:: =====================================================================
:: FUNCTION: CALL_THUNDERSTORE_API
:: PURPOSE: Fetches mod info from Thunderstore API
:: PARAMS: %1=Author, %2=ModName, %3=OutputFile
:: USES: TEMP_DIR, LOG_DIR
:: RETURNS: 0=Success, 2=Network error, 10=Invalid response
:: =====================================================================
:CALL_THUNDERSTORE_API
    setlocal EnableDelayedExpansion
    set "MOD_AUTHOR=%~1"
    set "MOD_NAME=%~2"
    set "OUTPUT_FILE=%~3"
    
    :: Ensure required directories exist
    if not exist "!LOG_DIR!" (
        mkdir "!LOG_DIR!" 2>nul || (
            call :HandleError 3
        )
    )
    
    set "API_LOG=!LOG_DIR!\!MOD_NAME!_api.log"
    
    :: Ensure parent directory of OUTPUT_FILE exists
    for %%F in ("!OUTPUT_FILE!") do (
        set "OUTPUT_DIR=%%~dpF"
        if not exist "!OUTPUT_DIR!" (
            mkdir "!OUTPUT_DIR!" 2>nul || (
                call :HandleError 3
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
            "if ($_.Exception -is [System.Net.WebException]) { exit 2 } " ^
            "elseif ($_.Exception -is [System.IO.IOException]) { exit 3 } " ^
            "else { exit 2 }" ^
        "}"

    if !errorlevel! equ 2 (
        call :HandleError 2 "!API_LOG!" "MOD_AUTHOR MOD_NAME API_URL"
    ) else if !errorlevel! equ 3 (
        call :HandleError 3 "!API_LOG!" "MOD_AUTHOR MOD_NAME API_URL"
    )

    :: Validate output file exists and has content
    if not exist "!OUTPUT_FILE!" (
        call :HandleError 10
        type "!API_LOG!" >> "!LOG_FILE!"
        type "!TEMP_RESPONSE!" >> "!LOG_FILE!"
    )

    :: Verify required data is present
    findstr /B "VERSION=" "!OUTPUT_FILE!" >nul || (
        call :HandleError 10
        type "!API_LOG!" >> "!LOG_FILE!"
        type "!TEMP_RESPONSE!" >> "!LOG_FILE!"
    )
    findstr /B "URL=" "!OUTPUT_FILE!" >nul || (
        call :HandleError 10
        type "!API_LOG!" >> "!LOG_FILE!"
        type "!TEMP_RESPONSE!" >> "!LOG_FILE!"
    )

    :: Clean up temporary response file
    if exist "!TEMP_RESPONSE!" del /f /q "!TEMP_RESPONSE!" 2>nul

    endlocal
    exit /b 0

::===================================================================
:: FUNCTION: COPYFILE
:: PURPOSE: Copies a file with fallback and error handling
:: PARAMS: %1=Source path, %2=Destination path, %3=Mod name
:: USES: LOG_DIR
:: RETURNS: 0=Success, 8=CopyError
::===================================================================
:CopyFile
    setlocal EnableDelayedExpansion
    set "SOURCE=%~1"
    set "DEST=%~2"
    set "MOD_NAME=%~3"
    
    :: Log the copy operation
    call :Log "Copying file for !MOD_NAME!: '!SOURCE!' -> '!DEST!'"
    
    :: Attempt standard copy first
    copy /Y "!SOURCE!" "!DEST!" >nul
    if !errorlevel! equ 0 (
        call :Log "Successfully copied file using copy command"
        endlocal
        exit /b 0
    )
    
    :: Log failure and attempt PowerShell fallback
    call :Log "Standard copy failed, attempting PowerShell fallback..."
    
    :: Create log file path for PowerShell operation
    set "PS_LOG=!LOG_DIR!\!MOD_NAME!_copy_ps.log"
    
    :: Attempt PowerShell copy with full error handling
    powershell -Command "$ErrorActionPreference = 'Stop';" ^
        "try {" ^
            "Copy-Item -Path '!SOURCE!'" ^
            " -Destination '!DEST!'" ^
            " -Force" ^
        "} catch {" ^
            "$_.Exception.Message | Out-File '!PS_LOG!';" ^
            "exit 1" ^
        "}" 2>"!PS_LOG!"
    
    if !errorlevel! equ 0 (
        call :Log "Successfully copied file using PowerShell fallback"
        endlocal
        exit /b 0
    )
    
    :: If both copy methods failed, handle the error
    call :HandleError 8 "!PS_LOG!" "SOURCE DEST MOD_NAME"
    endlocal
    exit /b 8

:: =====================================================================
:: FUNCTION: DOWNLOADMOD
:: PURPOSE: Downloads and validates specific mod package
:: PARAMS: %1=URL, %2=OutputPath, %3=ModName
:: USES: LOG_DIR
:: RETURNS: 0=Success, 1=NotFound, 2=DownloadError
:: =====================================================================
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
        call :HandleError 2 "!LOG_DIR!\!MOD_NAME!_download.log" "MOD_NAME URL OUTPUT"
    )

    :: Verify downloaded file exists and has content
    if not exist "!OUTPUT!" (
        call :HandleError 1
    )
    
    :: Zero-byte file check
    for %%A in ("!OUTPUT!") do (
        if %%~zA LEQ 0 (
            call :HandleError 2
            del "!OUTPUT!" 2>nul
        )
    )

    call :Log "Successfully downloaded !MOD_NAME!"
    endlocal
    exit /b 0

:: =====================================================================
:: FUNCTION: INSTALL_BEPINEX_PACK
:: PURPOSE: Installs BepInEx mod loader and verifies installation
:: PARAMS: None
:: USES: TEMP_DIR, EXTRACT_DIR, FOUND_PATH
:: RETURNS: 0=Success, 2-9=Various installation errors
:: =====================================================================
:INSTALL_BEPINEX_PACK
    setlocal EnableDelayedExpansion
    call :Log "Starting BepInExPack installation..."
    call :ColorEcho BLUE "► Installing BepInExPack..."

    :: Use centralized API helper to get version info
    set "API_OUTPUT=%TEMP_DIR%\BepInExPack_api.txt"
    call :CALL_THUNDERSTORE_API "!BEPINEX_AUTHOR!" "!BEPINEX_NAME!" "!API_OUTPUT!"
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
        call :HandleError 2 "!LOG_DIR!\BepInExPack_download.log" "DOWNLOAD_URL"
    )

    :: Extract BepInExPack
    call :Log "Extracting BepInExPack..." "console"
    if exist "!EXTRACT_ROOT!" rd /s /q "!EXTRACT_ROOT!" >nul 2>&1
    call :ExtractFiles "!ZIP_FILE!" "!EXTRACT_ROOT!" "BepInExPack"
    if !errorlevel! neq 0 (
        call :HandleError 9 "!LOG_DIR!\BepInExPack_extract.log" "ZIP_FILE EXTRACT_ROOT"
    )

    :: Log the extracted contents for debugging
    call :Log "Listing extracted contents:"
    dir /s /b "!EXTRACT_ROOT!" >> "!LOG_FILE!"

    :: Verify expected folder structure
    set "BEPINPACK_ROOT=!EXTRACT_ROOT!\BepInExPack"
    
    if not exist "!BEPINPACK_ROOT!\doorstop_config.ini" (
        call :HandleError 9 "" "BEPINPACK_ROOT"
    )

    if not exist "!BEPINPACK_ROOT!\winhttp.dll" (
        call :HandleError 9 "" "BEPINPACK_ROOT"
    )

    if not exist "!BEPINPACK_ROOT!\BepInEx" (
        call :HandleError 9 "" "BEPINPACK_ROOT"
    )

    :: Ensure target directories exist
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx" || (
        endlocal
        call :HandleError 3 "" "FOUND_PATH"
    )
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\core" || (
        endlocal
        call :HandleError 3 "" "FOUND_PATH"
    )
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\config" || (
        endlocal
        call :HandleError 3 "" "FOUND_PATH"
    )
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\plugins" || (
        endlocal
        call :HandleError 3 "" "FOUND_PATH"
    )
    call :CREATE_DIRECTORY "!FOUND_PATH!\BepInEx\patchers" || (
        endlocal
        call :HandleError 3 "" "FOUND_PATH"
    )

    :: Copy root files (doorstop and winhttp)
    call :Log "Copying BepInEx root files..."
    call :ColorEcho WHITE "* Installing BepInEx root files..."
    for %%F in (doorstop_config.ini winhttp.dll) do (
        copy /Y "!BEPINPACK_ROOT!\%%F" "!FOUND_PATH!\%%F" >nul || (
            call :HandleError 8 "" "FILE_NAME"
        )
    )

    :: Copy BepInEx folder contents
    call :Log "Copying BepInEx folder..."
    robocopy "!BEPINPACK_ROOT!\BepInEx" "!FOUND_PATH!\BepInEx" ^
        /E /DCOPY:T /R:0 /W:0 /NP ^
        /LOG+:"!LOG_DIR!\BepInExPack_install.log" >nul
    if !errorlevel! GEQ 8 (
        :: Fallback to xcopy if robocopy fails
        xcopy "!BEPINPACK_ROOT!\BepInEx\*" "!FOUND_PATH!\BepInEx\" /E /Y /Q >nul
        if !errorlevel! neq 0 (
            call :HandleError 8 "!LOG_DIR!\BepInExPack_install.log"
        )
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
        call :HandleError 6 "" "MISSING_FILES"
    )

    call :Log "BepInExPack installation completed successfully"
    call :ColorEcho GREEN "✓ BepInExPack installed successfully"
    endlocal
    exit /b 0

:: =====================================================================
:: FUNCTION: CLEANUP
:: PURPOSE: Post-installation resource management
:: PARAMS: None
:: MODIFIES: TEMP_DIR contents
:: RETURNS: INSTALL_STATUS
:: =====================================================================
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

:: =====================================================================
:: FUNCTION: DOWNLOADMODLIST
:: PURPOSE: Downloads and parses mod configuration
:: PARAMS: None
:: MODIFIES: MOD_LIST
:: RETURNS: 0=Success, 2=DownloadError, 14=NoValidMods
:: =====================================================================
:DownloadModlist
    setlocal EnableDelayedExpansion
    :: Delete existing modlist before download
    del "%TEMP_DIR%\modlist.ini" 2>nul
    :: Use Invoke-WebRequest to get content directly
    powershell -Command "$webClient = New-Object System.Net.WebClient;" ^
        "$webClient.Headers.Add('User-Agent', 'LCPlusInstaller/%VERSION%');" ^
        "try { " ^
            "$content = $webClient.DownloadString(" ^
                "'%MODLIST_URL%'" ^
            "); " ^
            "[System.IO.File]::WriteAllText('%TEMP_DIR%\\modlist.ini', $content)" ^
        "} catch { " ^
            "if ($_.Exception -is [System.Net.WebException]) { exit 2 } " ^
            "elseif ($_.Exception -is [System.IO.IOException]) { exit 3 } " ^
            "else { exit 2 } " ^
        "}; " ^
        2>"%LOG_DIR%\modlist_download.log"

    if !errorlevel! equ 2 (
        call :HandleError 2 "%LOG_DIR%\modlist_download.log" "MODLIST_URL TEMP_DIR"
    ) else if !errorlevel! equ 3 (
        call :HandleError 3 "%LOG_DIR%\modlist_download.log" "TEMP_DIR"
    )

    if not exist "%TEMP_DIR%\modlist.ini" (
        call :HandleError 3 "" "TEMP_DIR"
    )

    set "MOD_LIST="
    set /a "MOD_COUNT=0"
    for /f "usebackq tokens=*" %%a in ("%TEMP_DIR%\modlist.ini") do (
        set "LINE=%%a"
        set "LINE=!LINE: =!"
        if not "!LINE!"=="" (
            if "!LINE:~0,1!" neq ";" (
                for /f "tokens=1,2 delims=," %%b in ("!LINE!") do (
                    set "MOD_LIST=!MOD_LIST!%%b,%%c;"
                    set /a "MOD_COUNT+=1"
                )
            )
        )
    )
    if not defined MOD_LIST (
        call :HandleError 14 "" "MOD_LIST"
    )
    if defined MOD_LIST set "MOD_LIST=!MOD_LIST:~0,-1!"

    endlocal & set "MOD_LIST=%MOD_LIST%" & set "MOD_COUNT=%MOD_COUNT%"
    exit /b 0

:: =====================================================================
:: FUNCTION: InitializeLogging
:: PURPOSE: Sets up logging system and initial log entry
:: PARAMS: None
:: USES: LOG_FILE
:: RETURNS: 0=Success
:: =====================================================================
:InitializeLogging
    echo [%date% %time%] Lethal Company Plus installation started > "%LOG_FILE%"
    echo [%date% %time%] Initializing installer... >> "%LOG_FILE%"
    exit /b 0

:: =====================================================================
:: FUNCTION: EXTRACTFILES
:: PURPOSE: Extracts files from a ZIP archive
:: PARAMS: %1=ZIP file, %2=Destination directory, %3=Mod name
:: MODIFIES: None
:: RETURNS: 0=Success, 3=ExtractError
:: =====================================================================
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
            endlocal
            call :HandleError 3 "" "DESTINATION_DIR"
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
        call :HandleError 9 "" "ZIP_FILE DESTINATION_DIR"
    )

    endlocal
    exit /b 0