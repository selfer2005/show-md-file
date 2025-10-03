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
ROOT_DIR = config.get('settings', 'scanfolder', fallback='../fc_aliyun')
HOST = config.get('settings', 'host', fallback='0.0.0.0')
PORT = config.getint('settings', 'port', fallback=8000)

def format_time(timestamp):
    """将时间戳格式化为可读的日期时间字符串"""
    return time.strftime('%Y-%m-%d %H:%M', time.localtime(timestamp))

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
            "dir_name": dir_name,
            "file_name": file_name,
            "full_file_name": full_file_name,
            "modified_time": modified_time,
            "formatted_time": formatted_time
        })
    
    # 按修改时间降序排序（最新的在前面）
    md_files.sort(key=lambda x: x['modified_time'], reverse=True)
    
    return md_files

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    # 扫描MD文件
    md_files = scan_md_files(ROOT_DIR)
    
    return templates.TemplateResponse("index.html", {
        "request": request,
        "md_files": md_files,
        "root_dir": ROOT_DIR
    })

@app.get("/md-content/{file_path:path}")
async def get_md_content(file_path: str):
    """获取指定MD文件的内容"""
    full_path = Path(ROOT_DIR) / file_path
    
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