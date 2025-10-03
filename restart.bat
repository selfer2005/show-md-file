@echo off
setlocal enabledelayedexpansion

:: 设置日志文件
set LOG_FILE=run.log

:: 记录开始时间
echo [%date% %time%] Starting restart script >> %LOG_FILE%

:: 查找并结束已存在的Python进程
echo [%date% %time%] Checking for existing Python processes >> %LOG_FILE%
for /f "tokens=2 delims=," %%i in ('tasklist /fi "imagename eq python.exe" /fo csv ^| find /i "main.py"') do (
    set PID=%%~i
    echo [%date% %time%] Killing existing Python process with PID !PID! >> %LOG_FILE%
    taskkill /PID !PID! /F >nul 2>&1
)

:: 等待1秒确保进程已结束
timeout /t 1 /nobreak >nul

:: 启动新的Python应用
echo [%date% %time%] Starting new Python application >> %LOG_FILE%
start "MD File Browser" /B python main.py >> %LOG_FILE% 2>&1

:: 检查是否启动成功
timeout /t 2 /nobreak >nul
echo [%date% %time%] Checking if application started successfully >> %LOG_FILE%
tasklist /fi "imagename eq python.exe" | find /i "main.py" >nul
if %errorlevel%==0 (
    echo [%date% %time%] Application started successfully >> %LOG_FILE%
    echo Application started successfully. Check %LOG_FILE% for details.
) else (
    echo [%date% %time%] Failed to start application >> %LOG_FILE%
    echo Failed to start application. Check %LOG_FILE% for details.
)

echo [%date% %time%] Restart script completed >> %LOG_FILE%
echo.
echo Script completed. You can access the application at http://localhost:8000
echo Log file: %LOG_FILE%