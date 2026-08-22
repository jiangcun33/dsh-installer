@echo off
setlocal EnableExtensions
if not defined APPDATA set "APPDATA=%USERPROFILE%\AppData\Roaming"
if not defined LOCALAPPDATA set "LOCALAPPDATA=%USERPROFILE%\AppData\Local"
set "DSH_URL=http://127.0.0.1:3080"
set "DSH_APP_DIR=%LOCALAPPDATA%\DeepSeekHarness"
set "EDGE_PROFILE=%DSH_APP_DIR%\EdgeProfile"

rem Make sure Node.js and the per-user npm global bin are on PATH.
set "PATH=%LOCALAPPDATA%\Programs\nodejs;%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"

rem Find dsh.
set "DSH_CMD="
if exist "%APPDATA%\npm\dsh.cmd" set "DSH_CMD=%APPDATA%\npm\dsh.cmd"
if not defined DSH_CMD (
    for /f "delims=" %%i in ('where dsh 2^>nul') do if not defined DSH_CMD set "DSH_CMD=%%i"
)
if not defined DSH_CMD (
    echo [DSH] dsh was not found. Please run the DSH installer again, or install it manually:
    echo      npm install -g @deepseek-ai/dsh
    pause
    exit /b 1
)

rem Find Microsoft Edge.
set "EDGE="
for %%p in (
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    "%ProgramW6432%\Microsoft\Edge\Application\msedge.exe"
    "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
    "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
) do if exist "%%~p" if not defined EDGE set "EDGE=%%~p"
if not defined EDGE for /f "delims=" %%i in ('where msedge 2^>nul') do if not defined EDGE set "EDGE=%%i"
if not defined EDGE (
    echo [DSH] Microsoft Edge was not found.
    pause
    exit /b 1
)

rem Check whether the DSH server is already listening on 3080.
set "SERVER_UP="
call :check
if not defined SERVER_UP (
    echo [DSH] Starting DeepSeek Harness server...
    start "" /min "%ComSpec%" /c ""%DSH_CMD%" web --no-open"
    echo [DSH] Waiting for the server on %DSH_URL% ...
    for /l %%i in (1,1,90) do (
        call :check
        if defined SERVER_UP goto ready
        >nul 2>nul ping -n 2 127.0.0.1
    )
    echo [DSH] The server did not start in time.
    pause
    exit /b 1
)

:ready
rem Create an Edge app-mode shortcut so the standalone window keeps its own
rem taskbar icon (the whale icon), then launch it.
set "APP_LNK=%DSH_APP_DIR%\DeepSeekHarnessEdge.lnk"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=New-Object -ComObject WScript.Shell; $l=$s.CreateShortcut('%APP_LNK%'); $l.TargetPath='%EDGE%'; $l.Arguments='--app=%DSH_URL% --user-data-dir=%EDGE_PROFILE% --no-first-run --no-default-browser-check'; $l.IconLocation='%DSH_APP_DIR%\dsh.ico,0'; $l.Description='DeepSeek Harness'; $l.Save()"
start "" "%APP_LNK%"
exit /b 0

:check
set "SERVER_UP="
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3080" ^| findstr "LISTENING"') do set "SERVER_UP=1"
goto :eof
