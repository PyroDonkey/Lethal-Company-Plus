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