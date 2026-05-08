@echo off
setlocal

if not defined LOCAL_PORT set "LOCAL_PORT=8797"
if not defined REMOTE_PORT set "REMOTE_PORT=8797"
if not defined REMOTE_HOST set "REMOTE_HOST=127.0.0.1"
set "JUMP_USER=lijiyao"
set "JUMP_HOST=172.30.3.166"
set "TARGET_USER=lijiyao"
set "TARGET_HOST=gpu6000"
set "SSH_PASSWORD=Ljy05163417"

echo [INFO] Starting SSH tunnel:
echo        127.0.0.1:%LOCAL_PORT% -^> %REMOTE_HOST%:%REMOTE_PORT%
echo        jump=%JUMP_USER%@%JUMP_HOST% target=%TARGET_USER%@%TARGET_HOST%

where plink.exe >nul 2>nul
if not errorlevel 1 (
  plink -ssh -batch -pw "%SSH_PASSWORD%" -proxycmd "plink -ssh -batch -pw \"%SSH_PASSWORD%\" %JUMP_USER%@%JUMP_HOST% -nc %%host:%%port" -L %LOCAL_PORT%:%REMOTE_HOST%:%REMOTE_PORT% %TARGET_USER%@%TARGET_HOST%
  exit /b %errorlevel%
)

where ssh >nul 2>nul
if not errorlevel 1 (
  ssh -N -L %LOCAL_PORT%:%REMOTE_HOST%:%REMOTE_PORT% -J %JUMP_USER%@%JUMP_HOST% %TARGET_USER%@%TARGET_HOST%
  exit /b %errorlevel%
)

echo [ERROR] Neither plink nor ssh was found.
exit /b 1
