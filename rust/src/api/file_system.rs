// ─────────────────────────────────────────────────────────────
//  Unified File System Traversal  –  Local + Remote (SFTP)
// ─────────────────────────────────────────────────────────────

use flutter_rust_bridge::frb;
use crate::api::sftp_session;

/// A single file or directory entry used by both local and remote browsers.
#[frb]
#[derive(Clone, Debug)]
pub struct FileNode {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    pub size: u64,
    pub modified_timestamp: i64, // seconds since epoch; 0 if unavailable
}

/// Sorting criteria.
#[frb]
#[derive(Clone, Debug)]
pub enum SortBy {
    Name,
    Date,
    Size,
}

// ─────────────────────  LOCAL  ─────────────────────

/// List the contents of a local directory.
pub async fn list_local_dir(path: String, sort_by: SortBy) -> Result<Vec<FileNode>, String> {
    let mut entries = Vec::new();
    let mut rd = tokio::fs::read_dir(&path)
        .await
        .map_err(|e| format!("Cannot read local dir '{}': {}", path, e))?;

    while let Ok(Some(entry)) = rd.next_entry().await {
        let meta = entry.metadata().await.ok();
        let is_dir = meta.as_ref().map(|m| m.is_dir()).unwrap_or(false);
        let size = meta.as_ref().map(|m| m.len()).unwrap_or(0);
        let modified = meta
            .as_ref()
            .and_then(|m| m.modified().ok())
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        entries.push(FileNode {
            name: entry.file_name().to_string_lossy().to_string(),
            path: entry.path().to_string_lossy().to_string(),
            is_dir,
            size,
            modified_timestamp: modified,
        });
    }

    sort_entries(&mut entries, &sort_by);
    Ok(entries)
}

/// Create a new folder on the local filesystem.
pub async fn create_local_dir(path: String) -> Result<(), String> {
    tokio::fs::create_dir_all(&path)
        .await
        .map_err(|e| format!("mkdir failed: {e}"))
}

/// Delete a local file or directory (recursive).
pub async fn delete_local(path: String) -> Result<(), String> {
    let meta = tokio::fs::metadata(&path)
        .await
        .map_err(|e| format!("stat failed: {e}"))?;
    if meta.is_dir() {
        tokio::fs::remove_dir_all(&path)
            .await
            .map_err(|e| format!("rmdir failed: {e}"))
    } else {
        tokio::fs::remove_file(&path)
            .await
            .map_err(|e| format!("rm failed: {e}"))
    }
}

/// Rename a local file or directory.
pub async fn rename_local(old_path: String, new_path: String) -> Result<(), String> {
    tokio::fs::rename(&old_path, &new_path)
        .await
        .map_err(|e| format!("rename failed: {e}"))
}

// ─────────────────────  REMOTE (SFTP)  ─────────────────────

/// List the contents of a remote directory over SFTP.
pub async fn list_remote_dir(path: String, sort_by: SortBy) -> Result<Vec<FileNode>, String> {
    sftp_session::with_sftp(|sftp| {
        Box::pin(async move {
            let read_dir = sftp
                .read_dir(&path)
                .await
                .map_err(|e| format!("SFTP read_dir '{}': {}", path, e))?;

            let mut entries: Vec<FileNode> = read_dir
                .map(|e| {
                    let name = e.file_name();
                    let full_path = e.path();
                    let attrs = e.metadata();
                    let is_dir = attrs.is_dir();
                    let size = attrs.size.unwrap_or(0);
                    let modified = attrs
                        .modified()
                        .ok()
                        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                        .map(|d| d.as_secs() as i64)
                        .unwrap_or(0);

                    FileNode {
                        name,
                        path: full_path,
                        is_dir,
                        size,
                        modified_timestamp: modified,
                    }
                })
                .collect();

            sort_entries(&mut entries, &sort_by);
            Ok(entries)
        })
    })
    .await
}

/// Create a new directory on the remote server.
pub async fn create_remote_dir(path: String) -> Result<(), String> {
    sftp_session::with_sftp(|sftp| {
        Box::pin(async move {
            sftp.create_dir(&path)
                .await
                .map_err(|e| format!("SFTP mkdir failed: {e}"))
        })
    })
    .await
}

/// Delete a remote file.
pub async fn delete_remote_file(path: String) -> Result<(), String> {
    sftp_session::with_sftp(|sftp| {
        Box::pin(async move {
            sftp.remove_file(&path)
                .await
                .map_err(|e| format!("SFTP rm failed: {e}"))
        })
    })
    .await
}

/// Delete a remote directory.
pub async fn delete_remote_dir(path: String) -> Result<(), String> {
    sftp_session::with_sftp(|sftp| {
        Box::pin(async move {
            sftp.remove_dir(&path)
                .await
                .map_err(|e| format!("SFTP rmdir failed: {e}"))
        })
    })
    .await
}

/// Rename a remote file or directory.
pub async fn rename_remote(old_path: String, new_path: String) -> Result<(), String> {
    sftp_session::with_sftp(|sftp| {
        Box::pin(async move {
            sftp.rename(&old_path, &new_path)
                .await
                .map_err(|e| format!("SFTP rename failed: {e}"))
        })
    })
    .await
}

/// Copy a local file to another local path.
pub async fn copy_local(src_path: String, dst_path: String) -> Result<(), String> {
    tokio::fs::copy(&src_path, &dst_path)
        .await
        .map(|_| ())
        .map_err(|e| format!("Local copy failed: {e}"))
}

/// Copy a remote file to another remote path over SFTP.
pub async fn copy_remote(src_path: String, dst_path: String) -> Result<(), String> {
    sftp_session::with_sftp(|sftp| {
        Box::pin(async move {
            use tokio::io::{AsyncReadExt, AsyncWriteExt};
            use russh_sftp::protocol::OpenFlags;
            let mut src_file = sftp.open_with_flags(&src_path, OpenFlags::READ).await.map_err(|e| format!("SFTP src open failed: {e}"))?;
            let mut dst_file = sftp.open_with_flags(&dst_path, OpenFlags::CREATE | OpenFlags::TRUNCATE | OpenFlags::WRITE).await.map_err(|e| format!("SFTP dst open failed: {e}"))?;
            let mut buf = vec![0u8; 64 * 1024];
            loop {
                let n = src_file.read(&mut buf).await.map_err(|e| format!("SFTP read error: {e}"))?;
                if n == 0 { break; }
                dst_file.write_all(&buf[..n]).await.map_err(|e| format!("SFTP write error: {e}"))?;
            }
            dst_file.shutdown().await.map_err(|e| format!("SFTP close error: {e}"))?;
            Ok(())
        })
    })
    .await
}

// ─────────────────────  Helpers  ─────────────────────

fn sort_entries(entries: &mut Vec<FileNode>, sort_by: &SortBy) {
    entries.sort_by(|a, b| {
        b.is_dir.cmp(&a.is_dir).then_with(|| match sort_by {
            SortBy::Name => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
            SortBy::Date => b.modified_timestamp.cmp(&a.modified_timestamp),
            SortBy::Size => b.size.cmp(&a.size),
        })
    });
}
