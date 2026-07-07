use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

/// 虚拟内存文件结构
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct VirtualFile {
    pub path: String,
    pub content: String,
    pub updated_at: u64,
}

/// 内存虚拟文件系统沙盒 (Virtual VFS)：为无操作系统终端的手机移动端与 Web 网页端提供安全代码编辑环境
#[derive(Debug, Clone)]
pub struct VirtualVfs {
    files: Arc<Mutex<HashMap<String, VirtualFile>>>,
}

impl VirtualVfs {
    pub fn new() -> Self {
        Self {
            files: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    fn now_ts() -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0)
    }

    /// 在内存沙盒中创建或更新文件
    pub fn create_file(&self, path: &str, content: &str) -> Result<()> {
        let mut map = self
            .files
            .lock()
            .map_err(|_| anyhow!("Failed to lock VFS mutex"))?;
        let file = VirtualFile {
            path: path.to_string(),
            content: content.to_string(),
            updated_at: Self::now_ts(),
        };
        map.insert(path.to_string(), file);
        Ok(())
    }

    /// 更新文件内容
    pub fn update_file(&self, path: &str, content: &str) -> Result<()> {
        self.create_file(path, content)
    }

    /// 针对沙盒中现有代码文件执行局部修丁替换 (Patch)
    pub fn patch_code(&self, path: &str, find_str: &str, replace_str: &str) -> Result<()> {
        let mut map = self
            .files
            .lock()
            .map_err(|_| anyhow!("Failed to lock VFS mutex"))?;
        let file = map
            .get_mut(path)
            .ok_or_else(|| anyhow!("File not found in Virtual VFS: {}", path))?;

        if !file.content.contains(find_str) {
            return Err(anyhow!(
                "Target string not found in file {} during patch operation",
                path
            ));
        }
        file.content = file.content.replace(find_str, replace_str);
        file.updated_at = Self::now_ts();
        Ok(())
    }

    /// 读取沙盒中的文件内容
    pub fn read_file(&self, path: &str) -> Result<String> {
        let map = self
            .files
            .lock()
            .map_err(|_| anyhow!("Failed to lock VFS mutex"))?;
        let file = map
            .get(path)
            .ok_or_else(|| anyhow!("File not found in Virtual VFS: {}", path))?;
        Ok(file.content.clone())
    }

    /// 列举沙盒内所有的文件路径
    pub fn list_files(&self) -> Vec<String> {
        if let Ok(map) = self.files.lock() {
            let mut paths: Vec<String> = map.keys().cloned().collect();
            paths.sort();
            paths
        } else {
            Vec::new()
        }
    }

    /// 导出整个小程序工程制品包
    pub fn export_package(&self) -> Result<HashMap<String, String>> {
        let map = self
            .files
            .lock()
            .map_err(|_| anyhow!("Failed to lock VFS mutex"))?;
        let mut pkg = HashMap::new();
        for (k, v) in map.iter() {
            pkg.insert(k.clone(), v.content.clone());
        }
        Ok(pkg)
    }
}
