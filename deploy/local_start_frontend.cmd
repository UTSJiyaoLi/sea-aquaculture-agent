@echo off
setlocal

set ROOT_DIR=%~dp0..
set API_BASE=%NEXT_PUBLIC_API_BASE_URL%
if "%API_BASE%"=="" set API_BASE=http://127.0.0.1:8797

call conda activate rag_task
if errorlevel 1 (
  echo Failed to activate conda environment rag_task.
  echo Open an Anaconda Prompt or initialize conda for cmd.exe first.
  exit /b 1
)

cd /d "%ROOT_DIR%\apps\web"
call npm install
if errorlevel 1 exit /b 1

set NEXT_PUBLIC_API_BASE_URL=%API_BASE%
call npm run dev -- --port 3007
