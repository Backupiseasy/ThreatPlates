@echo off

SET BATCH_DIR=%~dp0

set command=%1
set version=%2
set ZIP_EXE="C:\Program Files\7-Zip\7z.exe"
set WOW_PATH=C:\Games\World of Warcraft\_retail_
set WOW_TEST_PATH=D:\Games\World of Warcraft - Test\_retail_
set WOW_INT_PATH=D:\Games\World of Warcraft - Int\_retail_
set WOW_PLAIN=F:\Games\World of Warcraft Plain\_retail_

set TP_PATH=F:\Eigene Dateien\Dokumente\WoW\ThreatPlates\Releases
set RELEASE_FILENAME=ThreatPlates_%version%.zip
set CLASSIC_RELEASE_FILENAME=ThreatPlatesClassic_%version%.zip


if "%command%"=="package" (CALL :Package)
if "%command%"=="package-classic" (CALL :PackageClassic)
if "%command%"=="plain" (CALL :Install-to-Plain)
if "%command%"=="help" (CALL :Print-Help)
if "%command%"=="" (CALL :Print-Help)
EXIT /B

:Package
set SOURCE=%BATCH_DIR%
set CMD=%ZIP_EXE% a -xr@exclude.lst "%TP_PATH%\%RELEASE_FILENAME%" "%SOURCE%"
echo Packaging %SOURCE% to %RELEASE_FILENAME%
%CMD% > nul
EXIT /B %ERRORLEVEL%

:PackageClassic
set SOURCE=%BATCH_DIR%
set CMD=%ZIP_EXE% a -xr@exclude.lst "%TP_PATH%\%CLASSIC_RELEASE_FILENAME%" "%SOURCE%"
echo Packaging %SOURCE% to %CLASSIC_RELEASE_FILENAME%
%CMD% > nul
EXIT /B %ERRORLEVEL%

:Install-to-Plain
set SOURCE=%BATCH_DIR%
set RELEASE_FILENAME=%TP_PATH%\ThreatPlates_plain.zip
DEL /S /Q "%RELEASE_FILENAME%" 2> nul > nul
@echo Package Source: %SOURCE%
%ZIP_EXE% a -xr@exclude.lst "%RELEASE_FILENAME%" "%SOURCE%" > nul
@echo Removing exiting installation in PLAIN environment: %WOW_PLAIN%\Interface\AddOns\TidyPlates_ThreatPlates
RMDIR /S /Q "%WOW_PLAIN%\Interface\AddOns\TidyPlates_ThreatPlates" 2> nul
@echo Removing exiting SavedVariables in PLAIN environment: %WOW_PLAIN%\WTF
DEL /S /Q /F "%WOW_PLAIN%\WTF\TidyPlates_ThreatPlates*.*" 2> nul
@echo Installing package to PLAIN environment %WOW_PLAIN%
%ZIP_EXE% x -o"%WOW_PLAIN%\Interface\AddOns" "%RELEASE_FILENAME%" > nul
DEL /S /Q /Q "%RELEASE_FILENAME%" > nul
EXIT /B %ERRORLEVEL%

:Print-Help
@echo on
@echo Usage: zip.bat ^<options^>
@echo   package ^<version^>      Create a new version package based on the the current ThreatPlates directory
@echo   plain                  Package up the current ThreatPlates directory and install it to the PLAIN environment
@echo   int                    Package up the current ThreatPlates directory and install it to the INTEGRATION environment
@echo   help                   Print this help message
@echo off
EXIT /B %ERRORLEVEL%
