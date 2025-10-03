# MD文件浏览器启动脚本
# 该脚本会启动应用并显示配置信息

# 设置控制台编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 显示标题
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          MD文件浏览器 - Vue 3 版本                           ║" -ForegroundColor Cyan
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

# 读取配置文件
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
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  应用配置信息" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 显示配置信息
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

# 检查端口是否被占用
Write-Host "🔍 检查端口占用情况..." -ForegroundColor Green
$PortInUse = $false
try {
    $Connections = netstat -ano | Select-String ":$Port\s"
    if ($Connections) {
        Write-Host "⚠️  警告: 端口 $Port 可能已被占用！" -ForegroundColor Yellow
        $PortInUse = $true
    } else {
        Write-Host "✅ 端口 $Port 可用" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  无法检查端口占用情况" -ForegroundColor Yellow
}

Write-Host ""

# 启动应用
Write-Host "🚀 正在启动应用..." -ForegroundColor Green

try {
    # 启动 Python 应用（不隐藏窗口，方便查看日志）
    $Process = Start-Process -FilePath "python" -ArgumentList "$MainPyPath" -PassThru
    
    # 等待应用启动
    Write-Host "⏳ 等待应用启动..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    # 检查进程是否还在运行
    if (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue) {
        Write-Host "✅ 应用启动成功！(PID: $($Process.Id))" -ForegroundColor Green
    } else {
        Write-Host "❌ 应用可能启动失败，请检查错误信息" -ForegroundColor Red
        pause
        exit 1
    }
} catch {
    Write-Host "❌ 启动失败: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  访问地址" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 显示访问地址
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

Write-Host "💡 提示:" -ForegroundColor Magenta
Write-Host "   • 应用正在后台运行" -ForegroundColor White
Write-Host "   • 使用 restart.ps1 重启应用" -ForegroundColor White
Write-Host "   • 在任务管理器中终止 python.exe 进程可停止应用" -ForegroundColor White
Write-Host ""

Write-Host "按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

