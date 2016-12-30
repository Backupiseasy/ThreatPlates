@echo off

set version=%1
set version2=%2
set ZIP_EXE="C:\Program Files\7-Zip\7z.exe"
set WOW_PATH=C:\Games\World of Warcraft
set WOW_TEST_PATH=D:\Games\World of Warcraft - Release
set TP_PATH=F:\Eigene Dateien\Dokumente\WoW\ThreatPlates\Releases

set TP_PACKAGE=%TP_PATH%\ThreatPlates_%version%.zip
set TP_SOURCE=%WOW_PATH%\Interface\Addons\TidyPlates_ThreatPlates

if "%1"=="test" (CALL :Prepare_Test) else (CALL :Zip)
EXIT /B

:Zip
%ZIP_EXE% a -xr@exclude.lst "%TP_PACKAGE%" "%TP_SOURCE%"
EXIT /B %ERRORLEVEL%

:Prepare_Test
set TP_PACKAGE=%TP_PATH%\ThreatPlates_%version2%.zip
RMDIR /S /Q "%WOW_TEST_PATH%\Interface\AddOns\TidyPlates_ThreatPlates"
DEL "%WOW_TEST_PATH%\WTF\Account\BLACKSALSIFY\SavedVariables\TidyPlates*.*"
%ZIP_EXE% x -o"%WOW_TEST_PATH%\Interface\AddOns" "%TP_PACKAGE%"
EXIT /B %ERRORLEVEL%