import os
import time
import markdown
import configparser
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pathlib import Path

app = FastAPI()

# 挂载静态文件目录
app.mount("/static", StaticFiles(directory="static"), name="static")

# 配置模板目录
templates = Jinja2Templates(directory="templates")

# 读取配置文件
config = configparser.ConfigParser()
# 指定UTF-8编码以避免中文编码问题
config.read('env.ini', encoding='utf-8')

# 从配置文件获取根目录，如果配置文件不存在或配置项不存在，则使用默认值
# 支持多个目录，用逗号分隔
ROOT_DIRS_STR = config.get('settings', 'scanfolder', fallback='../fc_aliyun')
# 分割并清理目录路径
ROOT_DIRS = [d.strip() for d in ROOT_DIRS_STR.split(',') if d.strip()]

# 从配置文件获取要排除的目录
EXCLUDE_DIRS_STR = config.get('settings', 'exclude_dirs', fallback='node_modules,venv,.venv,__pycache__,.git,dist,build')
# 分割并清理排除目录名称
EXCLUDE_DIRS = [d.strip() for d in EXCLUDE_DIRS_STR.split(',') if d.strip()]

HOST = config.get('settings', 'host', fallback='0.0.0.0')
PORT = config.getint('settings', 'port', fallback=8000)

def format_time(timestamp):
    """将时间戳格式化为可读的日期时间字符串"""
    return time.strftime('%Y-%m-%d %H:%M', time.localtime(timestamp))

def is_excluded_path(path, root_path, exclude_dirs):
    """检查路径是否应该被排除"""
    # 获取相对路径
    try:
        relative_path = path.relative_to(root_path)
        # 检查路径中的每一部分是否在排除列表中
        path_parts = relative_path.parts
        for part in path_parts:
            if part in exclude_dirs:
                return True
    except ValueError:
        # 如果路径不在root_path下，则不排除
        pass
    return False

def scan_md_files(root_dir):
    """扫描指定目录及其子目录下的所有MD文件"""
    md_files = []
    root_path = Path(root_dir)
    
    # 检查根目录是否存在
    if not root_path.exists():
        print(f"警告: 根目录 {root_path} 不存在")
        return md_files
    
    # 遍历所有文件
    for file_path in root_path.rglob("*.md"):
        # 检查是否应该排除此路径
        if is_excluded_path(file_path, root_path, EXCLUDE_DIRS):
            continue
            
        # 获取相对于根目录的路径
        relative_path = file_path.relative_to(root_path)
        # 获取目录名和文件名
        dir_name = str(relative_path.parent) if relative_path.parent != Path('.') else ''
        file_name = file_path.stem
        full_file_name = file_path.name
        
        # 获取文件的最后修改时间
        stat = file_path.stat()
        modified_time = stat.st_mtime
        
        # 格式化时间
        formatted_time = format_time(modified_time)
        
        md_files.append({
            "path": str(relative_path).replace("\\", "/"),  # 统一使用正斜杠
            "absolute_path": str(file_path),  # 保存绝对路径用于后续读取
            "root_dir": str(root_path),  # 保存根目录
            "dir_name": dir_name,
            "file_name": file_name,
            "full_file_name": full_file_name,
            "modified_time": modified_time,
            "formatted_time": formatted_time
        })
    
    # 按修改时间降序排序（最新的在前面）
    md_files.sort(key=lambda x: x['modified_time'], reverse=True)
    
    return md_files

# 全局变量：用于存储文件路径映射（相对路径 -> 绝对路径）
file_path_map = {}

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    global file_path_map
    file_path_map.clear()  # 清空旧的映射
    
    # 扫描所有配置的目录
    all_md_files = []
    for idx, root_dir in enumerate(ROOT_DIRS):
        md_files = scan_md_files(root_dir)
        
        # 为每个文件创建唯一的路径标识
        for file_info in md_files:
            # 使用 根目录索引::相对路径 作为唯一标识
            unique_path = f"{idx}::{file_info['path']}"
            file_info['unique_path'] = unique_path
            # 保存映射关系
            file_path_map[unique_path] = file_info['absolute_path']
            # 前端使用 unique_path 作为 path
            file_info['path'] = unique_path
            # 添加根目录标识（方便前端显示）
            file_info['root_dir_name'] = Path(root_dir).name if Path(root_dir).name else root_dir
        
        all_md_files.extend(md_files)
    
    # 按修改时间降序排序（最新的在前面）
    all_md_files.sort(key=lambda x: x['modified_time'], reverse=True)
    
    return templates.TemplateResponse("index.html", {
        "request": request,
        "md_files": all_md_files,
        "root_dirs": ROOT_DIRS  # 传递所有目录
    })

@app.get("/md-content/{file_path:path}")
async def get_md_content(file_path: str):
    """获取指定MD文件的内容"""
    # 从映射表中获取绝对路径
    if file_path in file_path_map:
        full_path = Path(file_path_map[file_path])
    else:
        # 兼容旧的路径格式（尝试在所有根目录中查找）
        full_path = None
        for root_dir in ROOT_DIRS:
            test_path = Path(root_dir) / file_path
            if test_path.exists() and test_path.is_file():
                full_path = test_path
                break
        
        if not full_path:
            return {"error": "File not found"}
    
    if not full_path.exists() or not full_path.is_file():
        return {"error": "File not found"}
    
    try:
        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # 将Markdown转换为HTML
        html_content = markdown.markdown(
            content,
            extensions=['fenced_code', 'tables', 'toc']
        )
        
        return {"content": html_content}
    except Exception as e:
        return {"error": f"Error reading file: {str(e)}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=HOST, port=PORT)