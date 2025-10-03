// 格式化所有时间显示
document.addEventListener('DOMContentLoaded', function() {
    // 获取所有文件项
    const fileItems = document.querySelectorAll('.file-item');
    
    // 为每个文件项添加点击事件
    fileItems.forEach(item => {
        item.addEventListener('click', function() {
            // 移除所有项的active类
            fileItems.forEach(i => i.classList.remove('active'));
            
            // 为当前点击项添加active类
            this.classList.add('active');
            
            // 获取文件路径
            const filePath = this.getAttribute('data-path');
            
            // 发送请求获取MD文件内容
            fetch(`/md-content/${filePath}`)
                .then(response => response.json())
                .then(data => {
                    if (data.error) {
                        document.getElementById('markdown-content').innerHTML = `<p style="color: red;">错误: ${data.error}</p>`;
                    } else {
                        document.getElementById('markdown-content').innerHTML = data.content;
                    }
                })
                .catch(error => {
                    document.getElementById('markdown-content').innerHTML = `<p style="color: red;">加载文件时出错: ${error}</p>`;
                });
        });
    });
    
    // 添加搜索功能
    const searchInput = document.getElementById('search-input');
    const fileList = document.getElementById('file-list');
    
    if (searchInput && fileList) {
        searchInput.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            const items = fileList.querySelectorAll('.file-item');
            
            items.forEach(item => {
                const fileName = item.getAttribute('data-name').toLowerCase();
                if (fileName.includes(searchTerm)) {
                    item.style.display = 'block';
                } else {
                    item.style.display = 'none';
                }
            });
        });
    }
});