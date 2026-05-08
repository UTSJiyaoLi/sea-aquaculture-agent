@echo off
title sea-aquaculture-web-3007
cd /d "C:\sea-aquaculture-agent\deploy\..\apps\web"
set VITE_API_BASE_URL=http://127.0.0.1:8797
if not exist node_modules call "C:\Program Files\nodejs\npm.cmd" install
if errorlevel 1 (
  pause
  exit /b 1
)
call "C:\Program Files\nodejs\npm.cmd" run dev -- -- --host 0.0.0.0 --port 3007
