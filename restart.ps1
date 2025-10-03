# MD文件浏览器重启脚本
# 该脚本会终止已存在的同目录main.py进程，然后启动新的实例

Write-Host "Starting restart script..."

# 获取当前目录的main.py路径
$CurrentDir = Get-Location
$MainPyPath = Join-Path $CurrentDir "main.py"

Write-Host "Checking for existing Python processes..."

# 使用Get-Process查找python进程
$Processes = Get-Process -Name "python" -ErrorAction SilentlyContinue
foreach ($Process in $Processes) {
    # 检查进程命令行是否包含当前目录的main.py
    try {
        # 使用Get-CimInstance获取进程详细信息
        $ProcessInfo = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($Process.Id)"
        if ($ProcessInfo.CommandLine -like "*$MainPyPath*") {
            Write-Host "Killing existing Python process with PID $($Process.Id)"
            Stop-Process -Id $Process.Id -Force
        }
    } catch {
        # 如果Get-CimInstance失败，尝试其他方法
        continue
    }
}

# 如果Get-CimInstance不可用，使用备用方法
if (!(Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
    # 使用tasklist命令作为备用方案
    $TaskListOutput = & tasklist /fi "imagename eq python.exe" /fo csv
    foreach ($Line in $TaskListOutput) {
        if ($Line -like "*main.py*") {
            $Parts = $Line -split '","'
            if ($Parts.Count -gt 1) {
                $PID = $Parts[1].Trim('"')
                if ($PID -match '^\d+$') {
                    Write-Host "Killing existing Python process with PID $PID (using tasklist)"
                    Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# 等待1秒确保进程已结束
Start-Sleep -Seconds 1

Write-Host "Starting new Python application..."
# 使用Start-Process启动应用
Start-Process -FilePath "python" -ArgumentList "$MainPyPath" -WindowStyle Hidden

# 等待2秒让应用启动
Start-Sleep -Seconds 2

Write-Host "Application started successfully."
Write-Host ""
Write-Host "Script completed. You can access the application at http://localhost:8000"