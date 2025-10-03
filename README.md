# MD文件浏览器

这是一个基于FastAPI的简单Web应用程序，用于浏览指定目录下的所有Markdown文件。

## 功能特性

- 自动扫描指定目录及其子目录下的所有.md文件
- 在左侧栏以树形结构显示所有MD文件
- 点击文件名在右侧显示文件内容
- 支持Markdown语法渲染（标题、列表、代码块等）
- 支持配置文件自定义扫描目录

## 目录结构

```
show-md-file/
├── main.py              # FastAPI主应用
├── requirements.txt     # 依赖包列表
├── env.ini             # 配置文件
├── restart.ps1         # PowerShell重启脚本
├── restart.bat         # Windows批处理重启脚本（备用）
├── run.log             # 运行日志文件
├── README.md            # 说明文档
├── templates/
│   └── index.html       # 主页面模板
└── static/
    ├── css/
    │   └── style.css    # 样式文件
    └── js/
        └── script.js    # JavaScript交互脚本
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

### Windows系统

双击运行 `restart.ps1` 脚本（推荐），它会：
1. 自动结束当前目录下已存在的应用进程
2. 启动新的应用实例
3. 记录操作日志到 `run.log` 文件

或者双击运行 `restart.bat` 脚本（备用方案）

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