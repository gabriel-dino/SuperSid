@echo off
setlocal
cd /d "%~dp0"
if exist "%ProgramFiles%\LOVE\love.exe" (
  start "Super Sid" "%ProgramFiles%\LOVE\love.exe" "%~dp0."
  exit /b 0
)
where love.exe >nul 2>nul
if %errorlevel%==0 (
  start "Super Sid" love.exe "%~dp0."
  exit /b 0
)
echo Install LOVE 11.5 from https://love2d.org then run this file again.
pause
