const { createApp, ref, computed, onMounted } = Vue;

createApp({
    setup() {
        // 响应式数据
        const files = ref(mdFiles || []);
        const searchQuery = ref('');
        const selectedFile = ref(null);
        const markdownContent = ref('');
        const loading = ref(false);
        const error = ref(null);

        // 计算属性
        const totalFiles = computed(() => files.value.length);

        const filteredFiles = computed(() => {
            if (!searchQuery.value.trim()) {
                return files.value;
            }
            const query = searchQuery.value.toLowerCase();
            return files.value.filter(file => 
                file.full_file_name.toLowerCase().includes(query) ||
                (file.dir_name && file.dir_name.toLowerCase().includes(query))
            );
        });

        // 方法
        const handleSearch = () => {
            // 搜索时重置选中
            if (selectedFile.value && !filteredFiles.value.some(f => f.path === selectedFile.value.path)) {
                selectedFile.value = null;
                markdownContent.value = '';
            }
        };

        const clearSearch = () => {
            searchQuery.value = '';
        };

        const selectFile = async (file) => {
            selectedFile.value = file;
            loading.value = true;
            error.value = null;
            markdownContent.value = '';

            try {
                const response = await fetch(`/md-content/${file.path}`);
                const data = await response.json();
                
                if (data.error) {
                    error.value = `错误: ${data.error}`;
                } else {
                    markdownContent.value = data.content;
                }
            } catch (err) {
                error.value = `加载文件时出错: ${err.message}`;
            } finally {
                loading.value = false;
            }
        };

        // 生命周期钩子
        onMounted(() => {
            console.log(`✨ Vue 3 应用已启动，共加载 ${files.value.length} 个文件`);
        });

        return {
            files,
            searchQuery,
            selectedFile,
            markdownContent,
            loading,
            error,
            totalFiles,
            filteredFiles,
            handleSearch,
            clearSearch,
            selectFile
        };
    }
}).mount('#app');
