## v1.4.1 (2025-02-13)

### Fixes

* Corrected mod names in `modlist.ini` to match their actual names on Thunderstore.
* Fixed the download URL for `modlist.ini` to use the `refs/heads/main` path.

### Refactoring

* Added cleanup of log files in the `:CLEANUP` function to keep the temporary directory tidy.

### Other Changes

* Removed the unused `TEMP_CFG` variable from the global configuration.

## v1.4.0 (2025-02-13)

### New Features

* Enforce mod installation order with indexed directories. This ensures that mods are installed in a specific sequence, which can be important for compatibility and dependency management.

### Changes

* Updated the mod list with new and updated mods:
    * FixRPCLag
    * Matty_Fixes
    * LethalConfig
    * VertexLibrary
    * NilsHUD
    * AccurateStaminaDisplay
    * MoonPriceDisplay
    * ShowCapacity
    * HideChat
    * SpiderPositionFix
    * CullFactory
    * IntroTweaks
    * EnemySoundFixes
    * JetpackFixes
    * MeleeFixes
    * RestoreMapper
    * MaskFixes
    * BarberFixes
    * WeedKillerFixes
    * Chameleon
    * RevisitStingers
    * UpturnedVariety
    * ShipLoot
    * CoilHeadStare
    * FireExitFlip
    * SuitSaver
    * OpenBodyCams
    * AlwaysHearActiveWalkies
    * LethalRichPresence


## v1.3.1 (2025-02-12)

### Fixes

* Improved error handling throughout the script, with more specific error codes and messages.
* Refined functionality in `:INSTALL_BEPINEX_PACK` to correctly copy BepInEx files.
* Enhanced error handling in PowerShell commands to capture and log more detailed errors.

### Code Style Improvements

* Removed unnecessary `setlocal` and `endlocal` blocks in some functions.
* Improved code readability with better spacing and indentation.

### Other Changes

* Added a new function, `:EXTRACTFILES`, to handle archive extraction with validation.
* Updated `:INSTALLSINGLEMOD` to use `:EXTRACTFILES` for extraction.

## v1.3.0 (2025-02-12)

### New Features

* Dynamically load the mod list from an external `modlist.ini` file. This allows updating the mod list without modifying the script.

### Refactoring

* Improved error handling and reporting, with new error codes for more specific messages.
* Enhanced PowerShell error handling to capture and log more detailed errors.
* Switched to `robocopy` for more robust backup and restore operations.
* Updated `WriteVersionInfo` function to include the mod author in the version file.
* Reorganized code for better clarity and maintainability.

### Other Changes

* Created a new `InitializeLogging` function to handle log file initialization.

## v1.2.2 (2025-02-11)

### Documentation

* Added extensive documentation throughout the script to improve readability and understanding.

### Refactoring

* Improved code organization and structure.
* Enhanced error handling and reporting in several functions.

## v1.2.1 (2025-02-10)

### Fixes

* **API URL:** Corrected the API URL in the `:InstallMod` function to ensure the correct order of author and mod name.
* **Confirmation Handling:** Improved confirmation handling by introducing a confirmation flag file and refining the installation flow.

### Other Changes

* Updated `:ShowModListAndConfirm` function to explicitly get user confirmation.
* Added cleanup of the confirmation flag file in the `:CLEANUP` function.
* **Removed the CompatibilityChecker mod from the installation list.** 

## v1.2.0 (2025-02-10)

### New Features

* Added the RuntimeIcons mod by LethalCompanyModding.

### Code Style Improvements

* Updated code formatting for improved readability and consistency.
* Standardized the use of `*` for download/extract messages.
* Improved error handling and exit codes in some functions.
* Modified the final exit message to reflect the installation status.

### Other Changes

*  Refined PowerShell code formatting with line continuations.
*  Removed unnecessary `console` parameters in some logging calls.

## v1.1.1 (2025-02-10)

### Fixes

* **API URL:** Corrected the API URL in the `:InstallMod` function to ensure the correct order of author and mod name.
* **Confirmation Handling:** Improved confirmation handling by introducing a confirmation flag file and refining the installation flow.

### Other Changes

* Updated `:ShowModListAndConfirm` function to explicitly get user confirmation.
* Added cleanup of the confirmation flag file in the `:CLEANUP` function.

## v1.0.0 (2025-02-10)

Initial release.