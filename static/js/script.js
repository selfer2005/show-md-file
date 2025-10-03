document.addEventListener('DOMContentLoaded', () => {
    const sidebar = document.getElementById('sidebar');
    const sidebarToggle = document.getElementById('sidebar-toggle');
    const sidebarClose = document.getElementById('sidebar-close');
    const sidebarOverlay = document.getElementById('sidebar-overlay');
    const markdownContainer = document.getElementById('markdown-content');
    const fileList = document.getElementById('file-list');
    const fileListEmpty = document.getElementById('file-list-empty');
    const searchInput = document.getElementById('search-input');

    const mobileQuery = window.matchMedia('(max-width: 960px)');
    let activeItem = null;

    const setSidebarState = (isOpen) => {
        document.body.classList.toggle('sidebar-open', isOpen);
        document.body.classList.toggle('no-scroll', isOpen && mobileQuery.matches);

        if (sidebarToggle) {
            sidebarToggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
        }
    };

    const closeSidebar = () => setSidebarState(false);

    const ensureDesktopState = () => {
        if (!mobileQuery.matches) {
            document.body.classList.remove('sidebar-open', 'no-scroll');
            if (sidebarToggle) {
                sidebarToggle.setAttribute('aria-expanded', 'false');
            }
        }
    };

    if (mobileQuery.addEventListener) {
        mobileQuery.addEventListener('change', ensureDesktopState);
    } else {
        mobileQuery.addListener(ensureDesktopState);
    }
    ensureDesktopState();

    const renderContent = (html) => {
        if (!markdownContainer) return;
        markdownContainer.innerHTML = html;
        const scroller = markdownContainer.closest('.markdown-content');
        if (scroller) {
            scroller.scrollTo({ top: 0, behavior: 'smooth' });
        }
    };

    const renderMessage = (message, tone = 'muted') => {
        const safeTone = ['muted', 'error'].includes(tone) ? tone : 'muted';
        renderContent(`<div class="state state--${safeTone}">${message}</div>`);
    };

    const handleFileActivate = (item) => {
        if (!item) return;

        if (activeItem) {
            activeItem.classList.remove('active');
        }

        activeItem = item;
        activeItem.classList.add('active');

        const rawPath = item.getAttribute('data-path');

        if (!rawPath) {
            renderMessage('未能识别文件路径。', 'error');
            return;
        }

        const normalizedPath = rawPath.replace(/\\/g, '/');
        const requestPath = normalizedPath
            .split('/')
            .map((segment) => encodeURIComponent(segment))
            .join('/');

        renderMessage('正在加载内容…');

        fetch(`/md-content/${requestPath}`)
            .then((response) => {
                if (!response.ok) {
                    throw new Error(`服务器响应异常：${response.status}`);
                }
                return response.json();
            })
            .then((data) => {
                if (data.error) {
                    renderMessage(`错误：${data.error}`, 'error');
                } else {
                    renderContent(data.content || '<p>此文件目前没有内容。</p>');
                }
            })
            .catch((error) => {
                renderMessage(`读取文件时出错：${error.message}`, 'error');
            })
            .finally(() => {
                if (mobileQuery.matches) {
                    closeSidebar();
                }
            });
    };

    if (fileList) {
        const items = Array.from(fileList.querySelectorAll('.file-item'));

        items.forEach((item) => {
            item.addEventListener('click', () => handleFileActivate(item));
            item.addEventListener('keydown', (event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    handleFileActivate(item);
                }
            });
        });
    }

    if (searchInput && fileList) {
        searchInput.addEventListener('input', (event) => {
            const keyword = event.target.value.trim().toLowerCase();
            const items = fileList.querySelectorAll('.file-item');
            let matchCount = 0;

            items.forEach((item) => {
                const wrapper = item.closest('.file-list__item');
                if (!wrapper) return;

                const fileName = (item.getAttribute('data-name') || '').toLowerCase();
                const isMatch = !keyword || fileName.includes(keyword);

                wrapper.style.display = isMatch ? '' : 'none';
                if (isMatch) {
                    matchCount += 1;
                }
            });

            if (fileListEmpty) {
                fileListEmpty.hidden = matchCount !== 0;
            }
        });
    }

    sidebarToggle?.addEventListener('click', () => {
        const isOpen = document.body.classList.contains('sidebar-open');
        setSidebarState(!isOpen);
    });

    sidebarClose?.addEventListener('click', closeSidebar);
    sidebarOverlay?.addEventListener('click', closeSidebar);

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && document.body.classList.contains('sidebar-open')) {
            closeSidebar();
        }
    });

    if (fileList) {
        const firstItem = fileList.querySelector('.file-item');
        if (firstItem) {
            handleFileActivate(firstItem);
        }
    } else {
        renderMessage('未检测到可用的 Markdown 文件。', 'error');
    }
});
