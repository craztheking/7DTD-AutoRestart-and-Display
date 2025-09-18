@echo off
rem Starts a dedicated server with live error and warning monitoring using PowerShell
rem
rem -quit, -batchmode, -nographics: Unity commands
rem -configfile			  : Allows server settings to be set up in an xml config file. Use no path if in same dir or full path.
rem -dedicated                    : Has to be the last option to start the dedicated server.

set LOGTIMESTAMP=
set RESTART_COUNT=0
set ERROR_COUNT=0
set WARNING_COUNT=0
set ERROR_LOG=server_errors.log
set WARNING_LOG=server_warnings.log
set SUMMARY_LOG=server_summary.log

echo Checking for server executable...
IF EXIST 7DaysToDieServer.exe (
	set GAMENAME=7DaysToDieServer
	set LOGNAME=output_log_dedi
	echo Found: 7DaysToDieServer.exe
) ELSE (
	IF EXIST 7DaysToDie.exe (
		set GAMENAME=7DaysToDie
		set LOGNAME=output_log
		echo Found: 7DaysToDie.exe
	) ELSE (
		echo ERROR: No server executable found!
		echo Looking for: 7DaysToDieServer.exe or 7DaysToDie.exe
		echo Current directory: %CD%
		echo Files in current directory:
		dir *.exe
		echo.
		echo Press any key to exit...
		pause
		exit
	)
)

echo Using executable: %GAMENAME%
echo Error log: %ERROR_LOG%
echo Warning log: %WARNING_LOG%
echo Summary log: %SUMMARY_LOG%
echo.

:restart_loop

:: Increment restart counter (except for first start)
if %RESTART_COUNT% GTR 0 (
    set /a RESTART_COUNT+=1
    echo This is restart #%RESTART_COUNT%
    echo.
) else (
    set /a RESTART_COUNT=1
    echo Initial server start
    echo.
)

:: --------------------------------------------
:: REMOVE OLD LOGS (only keep latest 20)
for /f "tokens=* skip=19" %%F in ('dir %LOGNAME%__* /o-d /tc /b 2^>nul') do del "%%F" 2>nul

:: --------------------------------------------
:: BUILDING TIMESTAMP FOR LOGFILE

:: Check WMIC is available
WMIC.EXE Alias /? >NUL 2>&1 || GOTO s_start

:: Use WMIC to retrieve date and time
FOR /F "skip=1 tokens=1-6" %%G IN ('WMIC Path Win32_LocalTime Get Day^,Hour^,Minute^,Month^,Second^,Year /Format:table') DO (
	IF "%%~L"=="" goto s_done
	Set _yyyy=%%L
	Set _mm=00%%J
	Set _dd=00%%G
	Set _hour=00%%H
	Set _minute=00%%I
	Set _second=00%%K
)
:s_done

:: Pad digits with leading zeros
Set _mm=%_mm:~-2%
Set _dd=%_dd:~-2%
Set _hour=%_hour:~-2%
Set _minute=%_minute:~-2%
Set _second=%_second:~-2%

Set LOGTIMESTAMP=__%_yyyy%-%_mm%-%_dd%__%_hour%-%_minute%-%_second%

:s_start

:: --------------------------------------------
:: STARTING SERVER

echo|set /p="251570" > steam_appid.txt
set SteamAppId=251570
set SteamGameId=251570

set LOGFILE=%~dp0%LOGNAME%%LOGTIMESTAMP%

echo Writing log file to: %LOGFILE%
echo.
echo ================================================
echo Starting 7 Days to Die Server... (Session #%RESTART_COUNT%)
echo Executable: %GAMENAME%
echo Config file: serverconfig.xml
echo Live monitoring will start automatically once server loads
echo Close this window or use CSMM to stop the server
echo Total sessions: %RESTART_COUNT% ^| Errors: %ERROR_COUNT% ^| Warnings: %WARNING_COUNT%
echo ================================================
echo.

:: Check if config file exists
if not exist serverconfig.xml (
    echo WARNING: serverconfig.xml not found in current directory!
    echo Server may fail to start properly.
    echo.
)

:: Write session start to summary log
echo. >> %SUMMARY_LOG%
echo ================================================ >> %SUMMARY_LOG%
echo SESSION #%RESTART_COUNT% STARTED: %DATE% %TIME% >> %SUMMARY_LOG%
echo Log file: %LOGFILE% >> %SUMMARY_LOG%
echo ================================================ >> %SUMMARY_LOG%

:: Create PowerShell monitoring script
echo Creating live monitor script...
(
echo $logFile = "%LOGFILE%"
echo $errorLog = "%ERROR_LOG%"
echo $warningLog = "%WARNING_LOG%"
echo $serverProcess = "%GAMENAME%"
echo $errorCount = %ERROR_COUNT%
echo $warningCount = %WARNING_COUNT%
echo $sessionNum = %RESTART_COUNT%
echo.
echo Write-Host "================================================" -ForegroundColor Cyan
echo Write-Host "LIVE ERROR/WARNING MONITOR STARTED" -ForegroundColor Cyan  
echo Write-Host "Monitoring: $logFile" -ForegroundColor Cyan
echo Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Cyan
echo Write-Host "================================================" -ForegroundColor Cyan
echo Write-Host ""
echo.
echo # Wait for log file to exist
echo while ^(-not ^(Test-Path $logFile^)^) {
echo     Start-Sleep -Seconds 2
echo     Write-Host "Waiting for log file to be created..."
echo }
echo.
echo Write-Host "Log file found! Starting live monitoring..." -ForegroundColor Green
echo Write-Host ""
echo.
echo $lastErrorCount = 0
echo $lastWarningCount = 0
echo.
echo while ^($true^) {
echo     # Check if server is still running
echo     $process = Get-Process -Name $serverProcess -ErrorAction SilentlyContinue
echo     if ^(-not $process^) {
echo         Write-Host ""
echo         Write-Host "Server process stopped! Monitor will close in 5 seconds..." -ForegroundColor Red
echo         Start-Sleep -Seconds 5
echo         exit
echo     }
echo.
echo     # Check for new errors and exceptions
echo     $errorLines = Select-String -Path $logFile -Pattern " ERR | EXC " -ErrorAction SilentlyContinue
echo     if ^($errorLines -and $errorLines.Count -gt $lastErrorCount^) {
echo         $newErrors = $errorLines[$lastErrorCount..^($errorLines.Count-1^)]
echo         foreach ^($errLine in $newErrors^) {
echo             $line = $errLine.Line
echo             # Skip shader/graphics errors
echo             if ^($line -notlike "*Shader*shader is not supported*" -and $line -notlike "*Microsoft Media Foundation*" -and $line -notlike "*graphics device is Null*" -and $line -notlike "*subshaders/fallbacks are suitable*"^) {
echo                 $errorCount++
echo                 $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
echo                 if ^($line -like "* EXC *"^) {
echo                     Write-Host "[EXCEPTION #$errorCount] $line" -ForegroundColor DarkRed
echo                     "[$timestamp] [EXCEPTION #$errorCount] $line" ^| Out-File -FilePath $errorLog -Append
echo                 } else {
echo                     Write-Host "[ERROR #$errorCount] $line" -ForegroundColor Red
echo                     "[$timestamp] [ERROR #$errorCount] $line" ^| Out-File -FilePath $errorLog -Append
echo                 }
echo             }
echo         }
echo         $lastErrorCount = $errorLines.Count
echo     }
echo.
echo     # Check for new warnings
echo     $warningLines = Select-String -Path $logFile -Pattern " WRN " -ErrorAction SilentlyContinue
echo     if ^($warningLines -and $warningLines.Count -gt $lastWarningCount^) {
echo         $newWarnings = $warningLines[$lastWarningCount..^($warningLines.Count-1^)]
echo         foreach ^($warnLine in $newWarnings^) {
echo             $line = $warnLine.Line
echo             # Skip shader/graphics warnings
echo             if ^($line -notlike "*Shader Unsupported*" -and $line -notlike "*pragma only_renderers*" -and $line -notlike "*Fallback off*" -and $line -notlike "*subshaders removal*" -and $line -notlike "*All subshaders removed*"^) {
echo                 $warningCount++
echo                 $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
echo                 Write-Host "[WARNING #$warningCount] $line" -ForegroundColor Yellow
echo                 "[$timestamp] [WARNING #$warningCount] $line" ^| Out-File -FilePath $warningLog -Append
echo             }
echo         }
echo         $lastWarningCount = $warningLines.Count
echo     }
echo.
echo     Start-Sleep -Seconds 5
echo }
echo.
echo Write-Host ""
echo Write-Host "Live monitoring stopped." -ForegroundColor Yellow
) > monitor.ps1

:: Start PowerShell monitor in a visible window with proper execution policy
echo Starting live monitor...
start "Error/Warning Monitor" powershell -ExecutionPolicy Bypass -NoExit -File monitor.ps1

:: Give monitor time to start
timeout /t 3 /nobreak >nul

echo Starting server process...
echo Command: %GAMENAME% -logfile "%LOGFILE%" -quit -batchmode -nographics -configfile=serverconfig.xml -dedicated
echo.

:: Start server normally (FOREGROUND - this is the key!)
%GAMENAME% -logfile "%LOGFILE%" -quit -batchmode -nographics -configfile=serverconfig.xml -dedicated

:: When we get here, the server has stopped
echo.
echo Server process has exited!
echo Exit code: %ERRORLEVEL%

:: Stop the PowerShell monitor (try multiple methods)
echo Stopping monitor...
taskkill /f /im powershell.exe /fi "WINDOWTITLE eq Error/Warning Monitor*" 2>nul
timeout /t 2 /nobreak >nul
taskkill /f /im powershell.exe 2>nul

:: Clean up monitor script
if exist monitor.ps1 del monitor.ps1

echo.
echo ================================================
echo Server stopped! Checking for any final errors and warnings...
echo ================================================

:: Final check and count
set SESSION_ERRORS=0
set SESSION_WARNINGS=0

:: Count total errors in this session's log
for /f %%i in ('findstr /i "ERR" "%LOGFILE%" 2^>nul ^| find /c /v ""') do set SESSION_ERRORS=%%i
if "%SESSION_ERRORS%"=="" set SESSION_ERRORS=0

:: Count total warnings in this session's log  
for /f %%i in ('findstr /i "WRN" "%LOGFILE%" 2^>nul ^| find /c /v ""') do set SESSION_WARNINGS=%%i
if "%SESSION_WARNINGS%"=="" set SESSION_WARNINGS=0

:: Update global counts (this is approximate since PowerShell was tracking live)
set /a ERROR_COUNT+=%SESSION_ERRORS%
set /a WARNING_COUNT+=%SESSION_WARNINGS%

:: Write session summary
echo SESSION #%RESTART_COUNT% ENDED: %DATE% %TIME% >> %SUMMARY_LOG%
echo Errors this session: %SESSION_ERRORS% >> %SUMMARY_LOG%
echo Warnings this session: %SESSION_WARNINGS% >> %SUMMARY_LOG%
echo Total errors so far: %ERROR_COUNT% >> %SUMMARY_LOG%
echo Total warnings so far: %WARNING_COUNT% >> %SUMMARY_LOG%
echo Exit code: %ERRORLEVEL% >> %SUMMARY_LOG%
echo. >> %SUMMARY_LOG%

echo.
echo ================================================
echo Server stopped! (After %RESTART_COUNT% sessions)
echo This session: %SESSION_ERRORS% errors, %SESSION_WARNINGS% warnings
echo Total errors: %ERROR_COUNT% ^| Total warnings: %WARNING_COUNT%
echo.
echo All errors/warnings were logged to:
echo - %ERROR_LOG% (all errors with timestamps)
echo - %WARNING_LOG% (all warnings with timestamps)
echo - %SUMMARY_LOG% (session summaries)
echo.
echo Restarting in 8 seconds...
echo Press Ctrl+C to cancel restart
echo ================================================
echo.

timeout /t 8

:: Clear screen and restart
cls
goto restart_loop
