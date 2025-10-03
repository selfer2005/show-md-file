#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
端口占用进程终止工具
使用方法: python kill_port.py <端口号>
示例: python kill_port.py 8002
"""

import sys
import subprocess
import re
import platform


def get_process_by_port(port):
    """
    根据端口号获取占用该端口的进程信息
    返回: [(PID, 进程名称), ...]
    """
    processes = []
    system = platform.system()
    
    try:
        if system == "Windows":
            # Windows 使用 netstat -ano
            result = subprocess.run(
                ['netstat', '-ano'],
                capture_output=True,
                text=True,
                encoding='gbk'  # Windows 中文系统使用 gbk 编码
            )
            
            # 解析输出，查找占用指定端口的进程
            for line in result.stdout.split('\n'):
                # 匹配类似: TCP    0.0.0.0:8002    0.0.0.0:0    LISTENING    12345
                # 或: TCP    127.0.0.1:8002    ...
                pattern = rf':\b{port}\b\s+.*?\s+(\d+)\s*$'
                match = re.search(pattern, line)
                
                if match:
                    pid = match.group(1)
                    # 获取进程名称
                    try:
                        process_info = subprocess.run(
                            ['tasklist', '/FI', f'PID eq {pid}', '/NH', '/FO', 'CSV'],
                            capture_output=True,
                            text=True,
                            encoding='gbk'
                        )
                        # 解析 CSV 输出获取进程名
                        if process_info.stdout:
                            parts = process_info.stdout.strip().split(',')
                            if len(parts) > 0:
                                process_name = parts[0].strip('"')
                                processes.append((pid, process_name))
                            else:
                                processes.append((pid, "未知"))
                    except Exception:
                        processes.append((pid, "未知"))
        
        else:  # Linux/Mac
            # Unix 系统使用 lsof
            result = subprocess.run(
                ['lsof', '-i', f':{port}', '-t'],
                capture_output=True,
                text=True
            )
            
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                if pid:
                    try:
                        # 获取进程名称
                        process_info = subprocess.run(
                            ['ps', '-p', pid, '-o', 'comm='],
                            capture_output=True,
                            text=True
                        )
                        process_name = process_info.stdout.strip()
                        processes.append((pid, process_name))
                    except Exception:
                        processes.append((pid, "未知"))
    
    except Exception as e:
        print(f"❌ 查询端口占用时出错: {e}")
        return []
    
    # 去重（同一个进程可能监听多个地址）
    seen = set()
    unique_processes = []
    for pid, name in processes:
        if pid not in seen:
            seen.add(pid)
            unique_processes.append((pid, name))
    
    return unique_processes


def kill_process(pid):
    """
    终止指定 PID 的进程
    """
    system = platform.system()
    
    try:
        if system == "Windows":
            # Windows 使用 taskkill
            result = subprocess.run(
                ['taskkill', '/F', '/PID', str(pid)],
                capture_output=True,
                text=True,
                encoding='gbk'
            )
            return result.returncode == 0
        else:
            # Unix 系统使用 kill
            result = subprocess.run(
                ['kill', '-9', str(pid)],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
    
    except Exception as e:
        print(f"❌ 终止进程时出错: {e}")
        return False


def main():
    # 显示标题
    print()
    print("═" * 60)
    print("  端口占用进程终止工具")
    print("═" * 60)
    print()
    
    # 检查命令行参数
    if len(sys.argv) < 2:
        print("❌ 错误: 缺少端口号参数")
        print()
        print("使用方法:")
        print(f"  python {sys.argv[0]} <端口号>")
        print()
        print("示例:")
        print(f"  python {sys.argv[0]} 8002")
        print()
        sys.exit(1)
    
    # 获取端口号
    try:
        port = int(sys.argv[1])
        if port < 1 or port > 65535:
            raise ValueError("端口号必须在 1-65535 之间")
    except ValueError as e:
        print(f"❌ 错误: 无效的端口号 '{sys.argv[1]}'")
        print(f"   {e}")
        print()
        sys.exit(1)
    
    print(f"🔍 正在查找占用端口 {port} 的进程...")
    print()
    
    # 查找占用端口的进程
    processes = get_process_by_port(port)
    
    if not processes:
        print(f"✅ 端口 {port} 未被占用")
        print()
        sys.exit(0)
    
    # 显示找到的进程
    print(f"📋 找到 {len(processes)} 个占用端口 {port} 的进程:")
    print()
    print(f"{'PID':<10} {'进程名称':<30}")
    print("-" * 50)
    for pid, name in processes:
        print(f"{pid:<10} {name:<30}")
    print()
    
    # 询问是否终止
    response = input("⚠️  是否终止这些进程? (y/n): ").strip().lower()
    
    if response != 'y' and response != 'yes':
        print("❌ 操作已取消")
        print()
        sys.exit(0)
    
    print()
    print("🔻 正在终止进程...")
    print()
    
    # 终止进程
    success_count = 0
    fail_count = 0
    
    for pid, name in processes:
        if kill_process(pid):
            print(f"✅ 成功终止进程 {pid} ({name})")
            success_count += 1
        else:
            print(f"❌ 无法终止进程 {pid} ({name})")
            fail_count += 1
    
    print()
    print("═" * 60)
    print(f"  完成: 成功 {success_count} 个, 失败 {fail_count} 个")
    print("═" * 60)
    print()
    
    if fail_count > 0:
        print("💡 提示: 如果终止失败，请尝试以管理员身份运行")
        print()
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()

