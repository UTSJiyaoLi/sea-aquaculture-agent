@echo off
setlocal

set "ROOT_DIR=%~dp0.."
if defined FRONTEND_DIR (
  set "FRONTEND_DIR=%FRONTEND_DIR%"
) else (
  set "FRONTEND_DIR=%ROOT_DIR%\apps\web"
)
if not defined UI_PORT set "UI_PORT=3007"
if not defined LOCAL_PORT set "LOCAL_PORT=8797"
if not defined REMOTE_PORT set "REMOTE_PORT=8797"
if not defined REMOTE_HOST set "REMOTE_HOST=127.0.0.1"

set "JUMP_USER=lijiyao"
set "JUMP_HOST=172.30.3.166"
set "TARGET_USER=lijiyao"
set "TARGET_HOST=gpu6000"
set "SSH_PASSWORD=Ljy05163417"

set "REQUESTED_UI_PORT=%UI_PORT%"
set "REQUESTED_LOCAL_PORT=%LOCAL_PORT%"
set "WEB_BOOT=%ROOT_DIR%\deploy\tmp_start_sea_aquaculture_frontend.cmd"
set "TUNNEL_BOOT=%ROOT_DIR%\deploy\tmp_start_sea_aquaculture_tunnel.cmd"

if not exist "%FRONTEND_DIR%\package.json" (
  echo [ERROR] Missing frontend project: %FRONTEND_DIR%\package.json
  echo [ERROR] Expected frontend directory: %ROOT_DIR%\apps\web
  goto :fail
)

set "NPM_CMD="
for /f "delims=" %%N in ('where npm.cmd 2^>nul') do (
  set "NPM_CMD=%%N"
  goto :npm_found
)
if exist "C:\Program Files\nodejs\npm.cmd" set "NPM_CMD=C:\Program Files\nodejs\npm.cmd"

:npm_found
if not defined NPM_CMD (
  echo [ERROR] npm.cmd not found. Please install Node.js.
  goto :fail
)

call :resolve_ui_port
if errorlevel 1 goto :fail
call :resolve_local_port
if errorlevel 1 goto :fail

set "API_BASE=http://127.0.0.1:%LOCAL_PORT%"
set "TUNNEL_TITLE=sea-aquaculture-tunnel-%LOCAL_PORT%"
set "WEB_TITLE=sea-aquaculture-web-%UI_PORT%"

echo [INFO] Launch config:
echo        FRONTEND_DIR=%FRONTEND_DIR%
echo        UI_PORT=%UI_PORT%
echo        LOCAL_PORT=%LOCAL_PORT%
echo        REMOTE_HOST=%REMOTE_HOST%
echo        REMOTE_PORT=%REMOTE_PORT%
echo        TARGET_HOST=%TARGET_HOST%
if not "%UI_PORT%"=="%REQUESTED_UI_PORT%" echo [INFO] UI port adjusted from %REQUESTED_UI_PORT% to %UI_PORT%.
if not "%LOCAL_PORT%"=="%REQUESTED_LOCAL_PORT%" echo [INFO] Local tunnel port adjusted from %REQUESTED_LOCAL_PORT% to %LOCAL_PORT%.

if /I not "%SKIP_TUNNEL%"=="1" (
  call :run_ensure_tunnel
  if errorlevel 1 (
    echo [ERROR] Backend tunnel is not healthy on http://127.0.0.1:%LOCAL_PORT%/health
    goto :fail
  )
) else (
  echo [WARN] Tunnel skipped by SKIP_TUNNEL=1.
)

call :run_ensure_frontend
if errorlevel 1 (
  echo [ERROR] Frontend page is not reachable on http://127.0.0.1:%UI_PORT%/
  goto :fail
)

echo [OK] Open: http://127.0.0.1:%UI_PORT%/
start "" "http://127.0.0.1:%UI_PORT%/"
echo [DONE] Sea aquaculture frontend is ready.
if not defined NO_PAUSE pause
exit /b 0

:resolve_ui_port
call :resolve_port "%REQUESTED_UI_PORT%" UI_PORT
exit /b %errorlevel%

:resolve_local_port
call :resolve_tunnel_port "%REQUESTED_LOCAL_PORT%" LOCAL_PORT "%UI_PORT%"
exit /b %errorlevel%

:run_ensure_tunnel
call :ensure_tunnel
exit /b %errorlevel%

:run_ensure_frontend
call :ensure_frontend
exit /b %errorlevel%

:ensure_tunnel
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:%LOCAL_PORT%/health' -TimeoutSec 3; if($r.StatusCode -ge 200){ exit 0 } else { exit 1 } } catch { exit 1 }"
if not errorlevel 1 (
  echo [INFO] Backend tunnel already healthy on %LOCAL_PORT%.
  exit /b 0
)

echo [INFO] Starting SSH tunnel to %TARGET_HOST% ...
where plink.exe >nul 2>nul
if not errorlevel 1 (
  (
    echo @echo off
    echo title %TUNNEL_TITLE%
    echo echo [INFO] Starting SSH tunnel %LOCAL_PORT% -^> %REMOTE_HOST%:%REMOTE_PORT%
    echo plink -ssh -batch -pw "%SSH_PASSWORD%" -proxycmd "plink -ssh -batch -pw \"%SSH_PASSWORD%\" %JUMP_USER%@%JUMP_HOST% -nc %%%%host:%%%%port" -L %LOCAL_PORT%:%REMOTE_HOST%:%REMOTE_PORT% %TARGET_USER%@%TARGET_HOST%
  ) > "%TUNNEL_BOOT%"
  start "%TUNNEL_TITLE%" cmd /k ""%TUNNEL_BOOT%""
  goto :wait_tunnel
)

where ssh >nul 2>nul
if not errorlevel 1 (
  (
    echo @echo off
    echo title %TUNNEL_TITLE%
    echo echo [INFO] Starting SSH tunnel %LOCAL_PORT% -^> %REMOTE_HOST%:%REMOTE_PORT%
    echo ssh -N -L %LOCAL_PORT%:%REMOTE_HOST%:%REMOTE_PORT% -J %JUMP_USER%@%JUMP_HOST% %TARGET_USER%@%TARGET_HOST%
  ) > "%TUNNEL_BOOT%"
  start "%TUNNEL_TITLE%" cmd /k ""%TUNNEL_BOOT%""
  goto :wait_tunnel
)

echo [ERROR] Neither plink nor ssh was found.
exit /b 1

:wait_tunnel
echo [INFO] Waiting for backend health...
powershell -NoProfile -Command "$ok=$false; for($i=0; $i -lt 90; $i++){ try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:%LOCAL_PORT%/health' -TimeoutSec 3; if($r.StatusCode -ge 200){ $ok=$true; break } } catch {}; Start-Sleep -Seconds 1 }; if($ok){ exit 0 } else { exit 1 }"
exit /b %errorlevel%

:ensure_frontend
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:%UI_PORT%/' -TimeoutSec 5; if($r.StatusCode -ge 200){ exit 0 } else { exit 1 } } catch { exit 1 }"
if not errorlevel 1 (
  echo [INFO] Frontend already healthy on %UI_PORT%.
  exit /b 0
)

echo [INFO] Starting frontend in %FRONTEND_DIR%
(
  echo @echo off
  echo title %WEB_TITLE%
  echo cd /d "%FRONTEND_DIR%"
  echo set VITE_API_BASE_URL=%API_BASE%
  echo if not exist node_modules call "%NPM_CMD%" install
  echo if errorlevel 1 ^(
  echo   pause
  echo   exit /b 1
  echo ^)
  echo call "%NPM_CMD%" run dev -- -- --host 0.0.0.0 --port %UI_PORT%
) > "%WEB_BOOT%"
start "%WEB_TITLE%" cmd /k ""%WEB_BOOT%""

:wait_frontend
echo [INFO] Waiting for frontend page...
powershell -NoProfile -Command "$ok=$false; for($i=0; $i -lt 120; $i++){ try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:%UI_PORT%/' -TimeoutSec 5; if($r.StatusCode -ge 200){ $ok=$true; break } } catch {}; Start-Sleep -Seconds 1 }; if($ok){ exit 0 } else { exit 1 }"
exit /b %errorlevel%

:resolve_port
setlocal
set "PORT=%~1"
if not defined PORT set "PORT=0"

:resolve_port_loop
call :is_http_ok "http://127.0.0.1:%PORT%/" 2
if not errorlevel 1 (
  endlocal & set "%~2=%PORT%" & exit /b 0
)
call :is_port_in_use "%PORT%"
if errorlevel 1 (
  endlocal & set "%~2=%PORT%" & exit /b 0
)
set /a PORT+=1
if %PORT% GTR 65535 (
  echo [ERROR] Cannot find free port for %~2.
  endlocal & exit /b 1
)
goto :resolve_port_loop

:resolve_tunnel_port
setlocal
set "PORT=%~1"
set "EXCLUDE=%~3"
if not defined PORT set "PORT=0"

:resolve_tunnel_port_loop
if "%PORT%"=="%EXCLUDE%" (
  set /a PORT+=1
  goto :resolve_tunnel_port_loop
)
call :is_http_ok "http://127.0.0.1:%PORT%/health" 2
if not errorlevel 1 (
  endlocal & set "%~2=%PORT%" & exit /b 0
)
call :is_port_in_use "%PORT%"
if errorlevel 1 (
  endlocal & set "%~2=%PORT%" & exit /b 0
)
set /a PORT+=1
if %PORT% GTR 65535 (
  echo [ERROR] Cannot find free port for %~2.
  endlocal & exit /b 1
)
goto :resolve_tunnel_port_loop

:is_http_ok
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -Uri '%~1' -TimeoutSec %~2; if($r.StatusCode -ge 200){ exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
exit /b %errorlevel%

:is_port_in_use
powershell -NoProfile -Command "$port=[int]('%~1'); $busy=Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue; if($busy){exit 0}else{exit 1}" >nul 2>nul
exit /b %errorlevel%

:fail
if not defined NO_PAUSE pause
exit /b 1
