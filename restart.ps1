# MD文件浏览器重启脚本
# 该脚本会终止已存在的同目录main.py进程，然后启动新的实例

# 设置控制台编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 显示标题
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          MD文件浏览器 - 重启服务                             ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 获取当前目录
$CurrentDir = Get-Location
$MainPyPath = Join-Path $CurrentDir "main.py"
$ConfigPath = Join-Path $CurrentDir "env.ini"

# 检查主程序文件是否存在
if (!(Test-Path $MainPyPath)) {
    Write-Host "❌ 错误: 找不到 main.py 文件！" -ForegroundColor Red
    Write-Host "   请确保在项目根目录运行此脚本。" -ForegroundColor Yellow
    pause
    exit 1
}

# ========== 第一步：读取配置信息 ==========
Write-Host "📋 读取配置信息..." -ForegroundColor Green

$ScanFolders = @()
$Port = "8000"  # 默认端口
$Host_Address = "0.0.0.0"  # 默认主机地址

if (Test-Path $ConfigPath) {
    $ConfigContent = Get-Content $ConfigPath -Encoding UTF8
    $InSettingsSection = $false
    
    foreach ($Line in $ConfigContent) {
        $Line = $Line.Trim()
        
        # 跳过注释和空行
        if ($Line -match "^#" -or $Line -eq "") {
            continue
        }
        
        # 检查是否进入 [settings] 部分
        if ($Line -eq "[settings]") {
            $InSettingsSection = $true
            continue
        }
        
        # 检查是否进入其他部分
        if ($Line -match "^\[.*\]$") {
            $InSettingsSection = $false
            continue
        }
        
        # 如果在 settings 部分，解析配置
        if ($InSettingsSection) {
            if ($Line -match "^scanfolder\s*=\s*(.+)$") {
                $Folder = $Matches[1].Trim()
                if ($Folder -ne "") {
                    $ScanFolders += $Folder
                }
            }
            elseif ($Line -match "^port\s*=\s*(\d+)$") {
                $Port = $Matches[1].Trim()
            }
            elseif ($Line -match "^host\s*=\s*(.+)$") {
                $Host_Address = $Matches[1].Trim()
            }
        }
    }
    
    Write-Host "✅ 配置文件加载成功" -ForegroundColor Green
} else {
    Write-Host "⚠️  警告: 找不到配置文件 env.ini，使用默认配置" -ForegroundColor Yellow
}

Write-Host ""

# ========== 第二步：检查并终止已存在的进程 ==========
Write-Host "🔍 检查是否有正在运行的应用进程..." -ForegroundColor Yellow

$KilledProcessCount = 0

# 方法1: 使用 Get-Process 和 Get-CimInstance (推荐)
$Processes = Get-Process -Name "python" -ErrorAction SilentlyContinue

if ($Processes) {
    foreach ($Process in $Processes) {
        try {
            # 使用Get-CimInstance获取进程详细信息
            $ProcessInfo = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($Process.Id)" -ErrorAction SilentlyContinue
            if ($ProcessInfo -and $ProcessInfo.CommandLine -like "*$MainPyPath*") {
                Write-Host "   🔻 找到进程 (PID: $($Process.Id))，正在终止..." -ForegroundColor Yellow
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
                $KilledProcessCount++
            }
        } catch {
            # 忽略错误，继续检查下一个进程
            continue
        }
    }
}

# 方法2: 使用 wmic 作为备用方案 (兼容性更好)
if ($KilledProcessCount -eq 0) {
    try {
        $WmicOutput = wmic process where "name='python.exe'" get processid,commandline 2>$null
        if ($WmicOutput) {
            $Lines = $WmicOutput -split "`n" | Where-Object { $_ -match "main\.py" }
            foreach ($Line in $Lines) {
                if ($Line -match "\s+(\d+)\s*$") {
                    $PID = $Matches[1]
                    Write-Host "   🔻 找到进程 (PID: $PID)，正在终止..." -ForegroundColor Yellow
                    Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
                    $KilledProcessCount++
                }
            }
        }
    } catch {
        # 忽略错误
    }
}

if ($KilledProcessCount -gt 0) {
    Write-Host "✅ 已终止 $KilledProcessCount 个进程" -ForegroundColor Green
    Write-Host "⏳ 等待进程完全退出..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
} else {
    Write-Host "✅ 没有发现正在运行的应用进程" -ForegroundColor Green
}

Write-Host ""

# ========== 第三步：显示配置信息 ==========
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  应用配置信息" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "🌐 服务器地址:  " -NoNewline -ForegroundColor Yellow
Write-Host "$Host_Address" -ForegroundColor White

Write-Host "🔌 监听端口:    " -NoNewline -ForegroundColor Yellow
Write-Host "$Port" -ForegroundColor White

Write-Host ""
Write-Host "📁 扫描目录:    " -ForegroundColor Yellow

if ($ScanFolders.Count -gt 0) {
    foreach ($Folder in $ScanFolders) {
        if (Test-Path $Folder) {
            Write-Host "   ✓ $Folder" -ForegroundColor Green
        } else {
            Write-Host "   ✗ $Folder" -ForegroundColor Red -NoNewline
            Write-Host " (目录不存在)" -ForegroundColor DarkRed
        }
    }
} else {
    Write-Host "   (未配置扫描目录)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ========== 第四步：检查端口 ==========
Write-Host "🔍 检查端口占用情况..." -ForegroundColor Green
$PortInUse = $false
try {
    $Connections = netstat -ano | Select-String ":$Port\s"
    if ($Connections) {
        Write-Host "⚠️  警告: 端口 $Port 可能已被占用！" -ForegroundColor Yellow
        Write-Host "   提示: 如果是之前的进程未完全退出，请稍等片刻" -ForegroundColor DarkYellow
        $PortInUse = $true
    } else {
        Write-Host "✅ 端口 $Port 可用" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  无法检查端口占用情况" -ForegroundColor Yellow
}

Write-Host ""

# ========== 第五步：启动新实例 ==========
Write-Host "🚀 正在启动新的应用实例..." -ForegroundColor Green

try {
    # 启动 Python 应用（隐藏窗口，在后台运行）
    $Process = Start-Process -FilePath "python" -ArgumentList "$MainPyPath" -WindowStyle Hidden -PassThru
    
    # 等待应用启动
    Write-Host "⏳ 等待应用启动..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    # 检查进程是否还在运行
    if (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue) {
        Write-Host "✅ 应用重启成功！(PID: $($Process.Id))" -ForegroundColor Green
    } else {
        Write-Host "❌ 应用可能启动失败，请检查错误信息" -ForegroundColor Red
        Write-Host "   提示: 可以手动运行 'python main.py' 查看详细错误" -ForegroundColor Yellow
        pause
        exit 1
    }
} catch {
    Write-Host "❌ 启动失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   提示: 请确保已安装 Python 和所需依赖" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host ""

# ========== 第六步：显示访问地址 ==========
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  访问地址" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "🌍 本地访问:    " -NoNewline -ForegroundColor Yellow
Write-Host "http://localhost:$Port" -ForegroundColor Cyan

Write-Host "🌍 局域网访问:  " -NoNewline -ForegroundColor Yellow

# 获取本机 IP 地址
try {
    $LocalIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    if ($LocalIP) {
        Write-Host "http://${LocalIP}:$Port" -ForegroundColor Cyan
    } else {
        Write-Host "(无法获取IP地址)" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "(无法获取IP地址)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ========== 完成信息 ==========
Write-Host "✨ 重启操作完成！" -ForegroundColor Green
Write-Host ""
Write-Host "💡 使用提示:" -ForegroundColor Magenta
Write-Host "   • 应用正在后台运行" -ForegroundColor White
Write-Host "   • 再次运行此脚本可重启服务" -ForegroundColor White
Write-Host "   • 使用 start.ps1 可查看更多启动信息" -ForegroundColor White
Write-Host "   • 在任务管理器中终止 python.exe 进程可停止应用" -ForegroundColor White
Write-Host ""

Write-Host "脚本执行完毕。" -ForegroundColor Gray
