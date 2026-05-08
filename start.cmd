@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "LAUNCHER=%ROOT_DIR%deploy\local_start_frontend.cmd"
if not defined FRONTEND_DIR set "FRONTEND_DIR=%ROOT_DIR%apps\web"

if not exist "%LAUNCHER%" (
  echo [ERROR] Missing launcher: %LAUNCHER%
  if not defined NO_PAUSE pause
  exit /b 1
)

call "%LAUNCHER%"
exit /b %errorlevel%
