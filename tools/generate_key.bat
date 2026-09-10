@echo off
setlocal
cd /d "%~dp0"

if "%~1"=="" (
    python "%~dp0generate_key.py"
    echo.
    pause
) else (
    python "%~dp0generate_key.py" %*
)
