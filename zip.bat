@echo off

set command=%1
set version=%2
set ZIP_EXE="C:\Program Files\7-Zip\7z.exe"
set WOW_PATH=C:\Games\World of Warcraft
set WOW_TEST_PATH=D:\Games\World of Warcraft - Test
set WOW_INT_PATH=D:\Games\World of Warcraft - Int

set TP_PATH=F:\Eigene Dateien\Dokumente\WoW\ThreatPlates\Releases
set TP_PACKAGE=%TP_PATH%\ThreatPlates_%version%.zip


if "%command%"=="release" (CALL :Zip-Release)
if "%command%"=="test" (CALL :Zip-Test)
if "%command%"=="prepare" (CALL :Prepare-Int)
EXIT /B

:Zip-Release
set TP_SOURCE=%WOW_PATH%\Interface\Addons\TidyPlates_ThreatPlates
%ZIP_EXE% a -xr@exclude.lst "%TP_PACKAGE%" "%TP_SOURCE%"
EXIT /B %ERRORLEVEL%

:Zip-Test
set TP_SOURCE=%WOW_TEST_PATH%\Interface\Addons\TidyPlates_ThreatPlates
%ZIP_EXE% a -xr@exclude.lst "%TP_PACKAGE%" "%TP_TEST_SOURCE%"
EXIT /B %ERRORLEVEL%


:Prepare-Int
RMDIR /S /Q "%WOW_INT_PATH%\Interface\AddOns\TidyPlates_ThreatPlates"
DEL "%WOW_INT_PATH%\WTF\Account\BLACKSALSIFY\SavedVariables\TidyPlates*.*"
%ZIP_EXE% x -o"%WOW_INT_PATH%\Interface\AddOns" "%TP_PACKAGE%"
EXIT /B %ERRORLEVEL%