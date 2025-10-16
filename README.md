# MD文件浏览器

**版本**: v2.3.0 | **状态**: 稳定版 🎉

这是一个基于FastAPI的简单Web应用程序，用于浏览指定目录下的所有Markdown文件。

## 功能特性

- 自动扫描指定目录及其子目录下的所有.md文件
- 在左侧栏以树形结构显示所有MD文件
- 点击文件名在右侧显示文件内容
- 支持Markdown语法渲染（标题、列表、代码块等）
- 支持配置文件自定义扫描目录
- **智能端口占用处理**（启动时自动检测并清理端口冲突）🆕
- 交互式管理界面（启动、停止、重启、监控一体化）

## 目录结构

```
show-md-file/
├── main.py                    # FastAPI主应用
├── requirements.txt           # 依赖包列表
├── env.ini                   # 配置文件
├── manage.ps1                # 交互式管理脚本（推荐）⭐
├── 管理.bat                   # 管理脚本快捷启动
├── 管理脚本使用说明.md         # 详细使用文档
├── start.ps1                 # PowerShell启动脚本
├── restart.ps1               # PowerShell重启脚本
├── restart.bat               # Windows批处理重启脚本（备用）
├── kill_port.py              # 端口管理工具
├── run.log                   # 运行日志文件
├── README.md                  # 说明文档
├── templates/
│   └── index.html             # 主页面模板
└── static/
    ├── css/
    │   └── style.css          # 样式文件
    └── js/
        └── script.js          # JavaScript交互脚本
```

## 安装依赖

```bash
pip install -r requirements.txt
```

## 配置

编辑 `env.ini` 文件来配置应用：

```ini
[settings]
# 要扫描的根目录路径（多个目录用逗号分隔）
scanfolder=../fc_aliyun

# 多目录示例（用逗号分隔）
# scanfolder=D:\documents\,E:\projects\,C:\notes\

# 服务器监听端口
port=8000

# 服务器主机地址
host=0.0.0.0
```

### 多目录配置

支持同时扫描多个目录，只需用逗号分隔：

```ini
scanfolder=D:\dir1\,D:\dir2\,D:\dir3\
```

## 使用方法

### Windows系统 - 交互式管理（推荐）⭐

**方式一：双击批处理文件**
```
管理.bat
```

**方式二：PowerShell命令**
```powershell
.\manage.ps1
```

这将启动一个功能强大的交互式管理界面，提供：
- 🚀 启动/停止/重启服务
- 🔧 **智能端口占用处理**（自动检测并清理端口冲突）🆕
- 📊 实时状态监控
- 📝 查看运行日志
- 🔍 实时监控模式
- 🌐 一键在浏览器中打开
- ⚙️ 配置管理

详细使用说明请查看 [管理脚本使用说明.md](管理脚本使用说明.md)

### Windows系统 - 传统方式

**快速启动：**
```powershell
.\start.ps1
```

**重启服务：**
```powershell
.\restart.ps1
```

### 其他系统

```bash
python main.py
```

## 访问应用

启动后，在浏览器中访问：http://localhost:8000

## 依赖包

- FastAPI: Web框架
- Uvicorn: ASGI服务器
- Jinja2: 模板引擎
- Markdown: Markdown解析器

详细的技术栈说明请查看 [技术栈说明.md](技术栈说明.md)

## 端口管理工具

如果遇到端口被占用的问题，可以使用端口管理工具：

```bash
python kill_port.py 8002
```

该工具会：
1. 自动查找占用指定端口的所有进程
2. 显示进程 PID 和名称
3. 询问确认后终止这些进程

## 日志

所有操作日志记录在 `run.log` 文件中。

---

## 📚 相关文档

- [管理脚本使用说明](管理脚本使用说明.md) - 详细的管理脚本使用指南
- [快速参考](快速参考.md) - 快速查询常用操作
- [技术栈说明](技术栈说明.md) - 项目技术架构和选型说明
- [功能演示](功能演示.md) - 功能演示和使用场景
- [更新日志](更新日志.md) - 版本更新历史
- [版本信息](VERSION.md) - 当前版本详细信息

---

## 📝 版本历史

查看 [更新日志.md](更新日志.md) 了解详细的版本更新历史。

**当前版本**: v2.3.0 (2025-10-16)
- ✨ 智能端口占用处理
- 🔧 自动清理冲突进程
- 📚 完善的文档体系

---

## 📄 许可证

MIT License

---

**享受便捷的 Markdown 文件浏览体验！** 🎊