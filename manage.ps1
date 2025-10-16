# MD文件浏览器 - 交互式管理脚本
# 提供完整的启动、停止、重启、状态监控功能

# 设置控制台编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 获取当前目录
$script:CurrentDir = Get-Location
$script:MainPyPath = Join-Path $CurrentDir "main.py"
$script:ConfigPath = Join-Path $CurrentDir "env.ini"
$script:LogPath = Join-Path $CurrentDir "run.log"

# 全局配置变量
$script:ScanFolders = @()
$script:Port = "8000"
$script:Host_Address = "0.0.0.0"

# ========== 工具函数 ==========

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          MD文件浏览器 - 交互式管理界面                       ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Read-Config {
    $script:ScanFolders = @()
    $script:Port = "8000"
    $script:Host_Address = "0.0.0.0"

    if (Test-Path $script:ConfigPath) {
        $ConfigContent = Get-Content $script:ConfigPath -Encoding UTF8
        $InSettingsSection = $false
        
        foreach ($Line in $ConfigContent) {
            $Line = $Line.Trim()
            
            if ($Line -match "^#" -or $Line -eq "") { continue }
            
            if ($Line -eq "[settings]") {
                $InSettingsSection = $true
                continue
            }
            
            if ($Line -match "^\[.*\]$") {
                $InSettingsSection = $false
                continue
            }
            
            if ($InSettingsSection) {
                if ($Line -match "^scanfolder\s*=\s*(.+)$") {
                    $FoldersStr = $Matches[1].Trim()
                    $script:ScanFolders = $FoldersStr -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                }
                elseif ($Line -match "^port\s*=\s*(\d+)$") {
                    $script:Port = $Matches[1].Trim()
                }
                elseif ($Line -match "^host\s*=\s*(.+)$") {
                    $script:Host_Address = $Matches[1].Trim()
                }
            }
        }
        return $true
    }
    return $false
}

function Get-AppProcess {
    $Processes = Get-Process -Name "python" -ErrorAction SilentlyContinue
    $AppProcesses = @()
    
    if ($Processes) {
        foreach ($Process in $Processes) {
            try {
                $ProcessInfo = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($Process.Id)" -ErrorAction SilentlyContinue
                if ($ProcessInfo -and $ProcessInfo.CommandLine -like "*$($script:MainPyPath)*") {
                    $AppProcesses += $Process
                }
            } catch {
                continue
            }
        }
    }
    
    return $AppProcesses
}

function Get-PortProcesses {
    param([int]$Port)
    
    $PortProcesses = @()
    
    try {
        # 使用 netstat 查找占用端口的进程
        $NetstatOutput = netstat -ano | Select-String ":$Port\s"
        
        if ($NetstatOutput) {
            foreach ($Line in $NetstatOutput) {
                # 提取 PID (最后一列)
                if ($Line -match "\s+(\d+)\s*$") {
                    $PID = $Matches[1]
                    
                    # 获取进程信息
                    try {
                        $Process = Get-Process -Id $PID -ErrorAction SilentlyContinue
                        if ($Process) {
                            $PortProcesses += @{
                                PID = $PID
                                Name = $Process.Name
                                Path = $Process.Path
                                Process = $Process
                            }
                        }
                    } catch {
                        continue
                    }
                }
            }
        }
    } catch {
        # 忽略错误
    }
    
    # 去重（同一个进程可能有多个连接）
    $UniqueProcesses = $PortProcesses | Sort-Object -Property PID -Unique
    
    return $UniqueProcesses
}

function Kill-PortProcesses {
    param([int]$Port)
    
    $PortProcesses = Get-PortProcesses -Port $Port
    
    if ($PortProcesses.Count -eq 0) {
        Write-Host "✅ 端口 $Port 未被占用" -ForegroundColor Green
        return $true
    }
    
    Write-Host "🔍 发现以下进程占用端口 ${Port}:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($ProcessInfo in $PortProcesses) {
        Write-Host "   • PID: $($ProcessInfo.PID)  |  " -NoNewline -ForegroundColor White
        Write-Host "进程名: $($ProcessInfo.Name)" -ForegroundColor Cyan
        if ($ProcessInfo.Path) {
            Write-Host "     路径: $($ProcessInfo.Path)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "❓ 是否要终止这些进程? " -NoNewline -ForegroundColor Yellow
    Write-Host "[Y/N]: " -NoNewline -ForegroundColor Cyan
    $Confirm = Read-Host
    
    if ($Confirm -eq 'Y' -or $Confirm -eq 'y') {
        Write-Host ""
        Write-Host "🔻 正在终止进程..." -ForegroundColor Yellow
        
        $KilledCount = 0
        foreach ($ProcessInfo in $PortProcesses) {
            try {
                Write-Host "   终止进程 PID: $($ProcessInfo.PID) ($($ProcessInfo.Name))..." -NoNewline -ForegroundColor White
                Stop-Process -Id $ProcessInfo.PID -Force -ErrorAction Stop
                Write-Host " ✅" -ForegroundColor Green
                $KilledCount++
            } catch {
                Write-Host " ❌" -ForegroundColor Red
                Write-Host "   错误: $($_.Exception.Message)" -ForegroundColor DarkRed
            }
        }
        
        if ($KilledCount -gt 0) {
            Write-Host ""
            Write-Host "⏳ 等待端口释放..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            
            # 再次检查端口
            $RemainingProcesses = Get-PortProcesses -Port $Port
            if ($RemainingProcesses.Count -eq 0) {
                Write-Host "✅ 端口 $Port 已释放 (终止了 $KilledCount 个进程)" -ForegroundColor Green
                Write-Host ""
                return $true
            } else {
                Write-Host "⚠️  端口仍被占用，还有 $($RemainingProcesses.Count) 个进程" -ForegroundColor Yellow
                Write-Host ""
                return $false
            }
        } else {
            Write-Host ""
            Write-Host "❌ 未能终止任何进程" -ForegroundColor Red
            Write-Host ""
            return $false
        }
    } else {
        Write-Host ""
        Write-Host "❌ 用户取消操作" -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
}

function Show-Status {
    param([bool]$Detailed = $false)
    
    $Processes = Get-AppProcess
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  服务状态" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Processes.Count -gt 0) {
        Write-Host "🟢 运行状态:    " -NoNewline -ForegroundColor Yellow
        Write-Host "运行中" -ForegroundColor Green
        
        foreach ($Process in $Processes) {
            Write-Host "   • PID: $($Process.Id)  |  " -NoNewline -ForegroundColor White
            Write-Host "启动时间: $($Process.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            
            if ($Detailed) {
                Write-Host "     CPU: $([math]::Round($Process.CPU, 2))s  |  " -NoNewline -ForegroundColor DarkGray
                Write-Host "内存: $([math]::Round($Process.WorkingSet64/1MB, 2)) MB" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "🔴 运行状态:    " -NoNewline -ForegroundColor Yellow
        Write-Host "未运行" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🌐 服务器地址:  " -NoNewline -ForegroundColor Yellow
    Write-Host "$script:Host_Address" -ForegroundColor White
    
    Write-Host "🔌 监听端口:    " -NoNewline -ForegroundColor Yellow
    Write-Host "$script:Port" -ForegroundColor White
    
    Write-Host ""
    Write-Host "📁 扫描目录:    " -ForegroundColor Yellow
    if ($script:ScanFolders.Count -gt 0) {
        foreach ($Folder in $script:ScanFolders) {
            if (Test-Path $Folder) {
                Write-Host "   ✓ $Folder" -ForegroundColor Green
            } else {
                Write-Host "   ✗ $Folder " -NoNewline -ForegroundColor Red
                Write-Host "(目录不存在)" -ForegroundColor DarkRed
            }
        }
    } else {
        Write-Host "   (未配置扫描目录)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    
    # 检查端口占用
    try {
        $Connections = netstat -ano | Select-String ":$script:Port\s"
        if ($Connections) {
            Write-Host "🔌 端口状态:    " -NoNewline -ForegroundColor Yellow
            if ($Processes.Count -gt 0) {
                Write-Host "正在使用 (本应用)" -ForegroundColor Green
            } else {
                Write-Host "被占用 (其他程序)" -ForegroundColor Red
            }
        } else {
            Write-Host "🔌 端口状态:    " -NoNewline -ForegroundColor Yellow
            Write-Host "空闲" -ForegroundColor Green
        }
    } catch {
        Write-Host "🔌 端口状态:    " -NoNewline -ForegroundColor Yellow
        Write-Host "无法检测" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "🌍 访问地址:" -ForegroundColor Yellow
    Write-Host "   • 本地:    http://localhost:$script:Port" -ForegroundColor Cyan
    
    try {
        $LocalIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
            $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254.*" 
        } | Select-Object -First 1).IPAddress
        
        if ($LocalIP) {
            Write-Host "   • 局域网:  http://${LocalIP}:$script:Port" -ForegroundColor Cyan
        }
    } catch {}
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Start-App {
    Write-Host "🚀 正在启动服务..." -ForegroundColor Green
    Write-Host ""
    
    # 检查是否已经运行
    $Processes = Get-AppProcess
    if ($Processes.Count -gt 0) {
        Write-Host "⚠️  服务已在运行中！" -ForegroundColor Yellow
        Write-Host "   如需重启，请选择重启选项" -ForegroundColor DarkYellow
        Write-Host ""
        return $false
    }
    
    # 检查main.py是否存在
    if (!(Test-Path $script:MainPyPath)) {
        Write-Host "❌ 错误: 找不到 main.py 文件！" -ForegroundColor Red
        Write-Host ""
        return $false
    }
    
    # 检查端口占用，如果被占用则提示用户处理
    $PortProcesses = Get-PortProcesses -Port $script:Port
    if ($PortProcesses.Count -gt 0) {
        Write-Host "⚠️  警告: 端口 $script:Port 已被占用！" -ForegroundColor Yellow
        Write-Host ""
        
        # 调用端口处理函数
        $PortCleared = Kill-PortProcesses -Port $script:Port
        
        if (-not $PortCleared) {
            Write-Host "❌ 端口未释放，无法启动服务" -ForegroundColor Red
            Write-Host "   请手动处理端口占用问题或修改配置文件中的端口号" -ForegroundColor Yellow
            Write-Host ""
            return $false
        }
    }
    
    try {
        # 启动应用
        $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessStartInfo.FileName = "python"
        $ProcessStartInfo.Arguments = "`"$script:MainPyPath`""
        $ProcessStartInfo.UseShellExecute = $false
        $ProcessStartInfo.RedirectStandardOutput = $true
        $ProcessStartInfo.RedirectStandardError = $true
        $ProcessStartInfo.CreateNoWindow = $true
        $ProcessStartInfo.WorkingDirectory = $script:CurrentDir
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessStartInfo
        
        # 启动进程
        $null = $Process.Start()
        
        Write-Host "⏳ 等待服务启动..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        
        # 检查是否成功启动
        $RunningProcesses = Get-AppProcess
        if ($RunningProcesses.Count -gt 0) {
            Write-Host "✅ 服务启动成功！" -ForegroundColor Green
            Write-Host "   PID: $($RunningProcesses[0].Id)" -ForegroundColor White
            Write-Host ""
            return $true
        } else {
            Write-Host "❌ 服务启动失败！" -ForegroundColor Red
            Write-Host "   提示: 运行 'python main.py' 查看详细错误" -ForegroundColor Yellow
            Write-Host ""
            return $false
        }
    } catch {
        Write-Host "❌ 启动失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        return $false
    }
}

function Stop-App {
    Write-Host "🛑 正在停止服务..." -ForegroundColor Yellow
    Write-Host ""
    
    $Processes = Get-AppProcess
    
    if ($Processes.Count -eq 0) {
        Write-Host "ℹ️  服务未在运行" -ForegroundColor Cyan
        Write-Host ""
        return $true
    }
    
    $KilledCount = 0
    foreach ($Process in $Processes) {
        try {
            Write-Host "   🔻 终止进程 PID: $($Process.Id)..." -ForegroundColor White
            Stop-Process -Id $Process.Id -Force -ErrorAction Stop
            $KilledCount++
        } catch {
            Write-Host "   ⚠️  无法终止进程 PID: $($Process.Id)" -ForegroundColor Yellow
        }
    }
    
    if ($KilledCount -gt 0) {
        Write-Host ""
        Write-Host "⏳ 等待进程完全退出..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        
        # 再次检查
        $RemainingProcesses = Get-AppProcess
        if ($RemainingProcesses.Count -eq 0) {
            Write-Host "✅ 服务已停止 (终止了 $KilledCount 个进程)" -ForegroundColor Green
            Write-Host ""
            return $true
        } else {
            Write-Host "⚠️  仍有 $($RemainingProcesses.Count) 个进程未能终止" -ForegroundColor Yellow
            Write-Host ""
            return $false
        }
    }
    
    return $false
}

function Restart-App {
    Write-Host "🔄 正在重启服务..." -ForegroundColor Cyan
    Write-Host ""
    
    # 先停止
    $StopResult = Stop-App
    
    # 等待一下
    Start-Sleep -Seconds 1
    
    # 再启动
    $StartResult = Start-App
    
    if ($StartResult) {
        Write-Host "✨ 服务重启成功！" -ForegroundColor Green
        Write-Host ""
        return $true
    } else {
        Write-Host "❌ 服务重启失败！" -ForegroundColor Red
        Write-Host ""
        return $false
    }
}

function Show-Logs {
    param([int]$Lines = 50)
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  服务日志 (最近 $Lines 行)" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if (Test-Path $script:LogPath) {
        $LogContent = Get-Content $script:LogPath -Tail $Lines -ErrorAction SilentlyContinue
        if ($LogContent) {
            foreach ($Line in $LogContent) {
                Write-Host $Line -ForegroundColor Gray
            }
        } else {
            Write-Host "   (日志文件为空)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "   (日志文件不存在)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
    Write-Host "  操作菜单" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  [1] 启动服务" -ForegroundColor White
    Write-Host "  [2] 停止服务" -ForegroundColor White
    Write-Host "  [3] 重启服务" -ForegroundColor White
    Write-Host "  [4] 查看状态" -ForegroundColor White
    Write-Host "  [5] 查看日志" -ForegroundColor White
    Write-Host "  [6] 实时监控" -ForegroundColor White
    Write-Host "  [7] 刷新配置" -ForegroundColor White
    Write-Host "  [8] 在浏览器中打开" -ForegroundColor White
    Write-Host "  [9] 清理端口占用" -ForegroundColor White
    Write-Host "  [0] 退出" -ForegroundColor White
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
    Write-Host ""
}

function Start-Monitor {
    Write-Host "🔍 进入实时监控模式 (按 Ctrl+C 退出)" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        while ($true) {
            Clear-Host
            Show-Banner
            Show-Status -Detailed $true
            
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
            Write-Host "  🔄 自动刷新中... (按 Ctrl+C 返回主菜单)" -ForegroundColor Gray
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
            Write-Host ""
            
            Start-Sleep -Seconds 3
        }
    } catch {
        Write-Host ""
        Write-Host "已退出监控模式" -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds 1
    }
}

function Open-Browser {
    Write-Host "🌐 正在浏览器中打开..." -ForegroundColor Green
    Write-Host ""
    
    $Url = "http://localhost:$script:Port"
    
    try {
        Start-Process $Url
        Write-Host "✅ 已在默认浏览器中打开: $Url" -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "❌ 无法打开浏览器" -ForegroundColor Red
        Write-Host "   请手动访问: $Url" -ForegroundColor Yellow
        Write-Host ""
    }
}

# ========== 主程序 ==========

# 检查main.py是否存在
if (!(Test-Path $script:MainPyPath)) {
    Clear-Host
    Write-Host ""
    Write-Host "❌ 错误: 找不到 main.py 文件！" -ForegroundColor Red
    Write-Host "   请确保在项目根目录运行此脚本。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "按任意键退出..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# 读取配置
$ConfigLoaded = Read-Config

# 主循环
while ($true) {
    Show-Banner
    Show-Status
    Show-Menu
    
    Write-Host "请选择操作 [0-9]: " -NoNewline -ForegroundColor Yellow
    $Choice = Read-Host
    Write-Host ""
    
    switch ($Choice) {
        "1" {
            Start-App
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "2" {
            Stop-App
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "3" {
            Restart-App
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "4" {
            # 状态已经在主界面显示了
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "5" {
            Show-Logs
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "6" {
            Start-Monitor
        }
        "7" {
            Write-Host "🔄 正在重新加载配置..." -ForegroundColor Cyan
            $ConfigLoaded = Read-Config
            Write-Host "✅ 配置已刷新" -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 1
        }
        "8" {
            Open-Browser
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "9" {
            Write-Host "🔧 正在检查端口 $script:Port 占用情况..." -ForegroundColor Cyan
            Write-Host ""
            $PortCleared = Kill-PortProcesses -Port $script:Port
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "0" {
            Write-Host "👋 再见！" -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
        default {
            Write-Host "⚠️  无效的选择，请输入 0-9 之间的数字" -ForegroundColor Red
            Write-Host ""
            Start-Sleep -Seconds 2
        }
    }
}

