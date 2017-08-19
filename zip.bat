@echo off

SET BATCH_DIR=%~dp0

set command=%1
set version=%2
set ZIP_EXE="C:\Program Files\7-Zip\7z.exe"
set WOW_PATH=C:\Games\World of Warcraft
set WOW_TEST_PATH=D:\Games\World of Warcraft - Test
set WOW_INT_PATH=D:\Games\World of Warcraft - Int
set WOW_PLAIN=F:\Games\World of Warcraft French

set TP_PATH=F:\Eigene Dateien\Dokumente\WoW\ThreatPlates\Releases
set TP_PACKAGE=%TP_PATH%\ThreatPlates_%version%.zip


if "%command%"=="release" (CALL :Zip-Release)
if "%command%"=="test" (CALL :Zip-Test)
if "%command%"=="package" (CALL :Package)
if "%command%"=="plain" (CALL :Install-to-Plain)
if "%command%"=="help" (CALL :Print-Help)
if "%command%"=="" (CALL :Print-Help)
EXIT /B

:Zip-Release
set TP_SOURCE=%WOW_PATH%\Interface\Addons\TidyPlates_ThreatPlates
set CMD=%ZIP_EXE% a -xr@exclude.lst "%TP_PACKAGE%" "%TP_SOURCE%"
echo Packaging: %CMD%
%CMD%
EXIT /B %ERRORLEVEL%

:Zip-Test
set TP_TEST_SOURCE=%WOW_TEST_PATH%\Interface\Addons\TidyPlates_ThreatPlates
set CMD=%ZIP_EXE% a -xr@exclude.lst "%TP_PACKAGE%" "%TP_TEST_SOURCE%"
echo Packaging: %CMD%
%CMD%
EXIT /B %ERRORLEVEL%


:Package
set SOURCE=%BATCH_DIR%
set CMD=%ZIP_EXE% a -xr@exclude.lst "%TP_PACKAGE%" "%SOURCE%"
echo Packaging %SOURCE% to ThreatPlates_%version%.zip
%CMD% > nul
EXIT /B %ERRORLEVEL%

:Install-to-Plain
set SOURCE=%BATCH_DIR%
set TP_PACKAGE=%TP_PATH%\ThreatPlates_plain.zip
DEL /S /Q /Q "%TP_PACKAGE%" > nul
@echo Package Source: %SOURCE%
%ZIP_EXE% a -xr@exclude.lst "%TP_PACKAGE%" "%SOURCE%" > nul
@echo Removing exiting installation in PLAIN environment: %WOW_PLAIN%\WTF
RMDIR /S /Q "%WOW_PLAIN%\Interface\AddOns\TidyPlates_ThreatPlates" 2> nul
@echo Removing exiting SavedVariables in PLAIN environment: %WOW_PLAIN%\Interface\AddOns\TidyPlates_ThreatPlates
DEL /S /Q /F "%WOW_PLAIN%\WTF\TidyPlates_ThreatPlates*.*" 2> nul
@echo Installing package to PLAIN environment %WOW_PLAIN%
%ZIP_EXE% x -o"%WOW_PLAIN%\Interface\AddOns" "%TP_PACKAGE%" > nul
DEL /S /Q /Q "%TP_PACKAGE%" > nul
EXIT /B %ERRORLEVEL%

:Print-Help
@echo on
@echo Usage: zip.bat ^<options^>
@echo   package ^<version^>    Create a new version package based on the the current ThreatPlates directory
@echo   plain                  Package up the current ThreatPlates directory and install it to the PLAIN environment
@echo   help                   Print this help message
@echo off
EXIT /B %ERRORLEVEL%
