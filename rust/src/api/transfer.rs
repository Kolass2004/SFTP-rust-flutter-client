// ─────────────────────────────────────────────────────────────
//  Transfer Engine  –  cross‑system copy with progress streams
// ─────────────────────────────────────────────────────────────

use flutter_rust_bridge::frb;
use crate::api::sftp_session;
use crate::frb_generated::StreamSink;
use crate::api::TOKIO_RT;
use russh_sftp::protocol::OpenFlags;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Instant;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

const CHUNK_SIZE: usize = 64 * 1024; // 64 KiB

/// Direction of a file transfer.
#[frb]
#[derive(Clone, Debug)]
pub enum TransferDirection {
    LocalToRemote,
    RemoteToLocal,
}

/// Real‑time metrics pushed to Flutter every ~100 ms.
#[frb]
#[derive(Clone, Debug)]
pub struct TransferProgress {
    pub transfer_id: String,
    pub file_name: String,
    pub total_bytes: u64,
    pub transferred_bytes: u64,
    pub percentage: f64,
    pub speed_bytes_per_sec: f64,
    pub eta_seconds: f64,
    pub is_complete: bool,
    pub error: String,
}

use once_cell::sync::Lazy;
use tokio::sync::Mutex;
use std::collections::HashMap;

static CANCEL_TOKENS: Lazy<Mutex<HashMap<String, Arc<AtomicBool>>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

/// Cancel an in‑progress transfer by its ID.
pub async fn cancel_transfer(transfer_id: String) {
    let lock = CANCEL_TOKENS.lock().await;
    if let Some(token) = lock.get(&transfer_id) {
        token.store(true, Ordering::Relaxed);
    }
}

/// Start a file transfer (upload or download).
pub fn transfer_file(
    transfer_id: String,
    direction: TransferDirection,
    local_path: String,
    remote_path: String,
    sink: StreamSink<TransferProgress>,
) {
    TOKIO_RT.spawn(async move {
        let cancel = Arc::new(AtomicBool::new(false));
        {
            let mut lock = CANCEL_TOKENS.lock().await;
            lock.insert(transfer_id.clone(), cancel.clone());
        }

        let result = match direction {
            TransferDirection::LocalToRemote => {
                do_upload(transfer_id.clone(), local_path.clone(), remote_path.clone(), sink.clone(), cancel.clone()).await
            }
            TransferDirection::RemoteToLocal => {
                do_download(transfer_id.clone(), remote_path.clone(), local_path.clone(), sink.clone(), cancel.clone()).await
            }
        };

        if let Err(e) = result {
            let file_name = std::path::Path::new(&local_path)
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            let _ = sink.add(TransferProgress {
                transfer_id: transfer_id.clone(),
                file_name,
                total_bytes: 0,
                transferred_bytes: 0,
                percentage: 0.0,
                speed_bytes_per_sec: 0.0,
                eta_seconds: 0.0,
                is_complete: true,
                error: e,
            });
        }

        let mut lock = CANCEL_TOKENS.lock().await;
        lock.remove(&transfer_id);
    });
}

async fn do_upload(
    transfer_id: String,
    local_path: String,
    remote_path: String,
    sink: StreamSink<TransferProgress>,
    cancel: Arc<AtomicBool>,
) -> Result<(), String> {
    let meta = tokio::fs::metadata(&local_path)
        .await
        .map_err(|e| format!("Cannot stat local file: {e}"))?;
    let total = meta.len();
    let file_name = std::path::Path::new(&local_path)
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    let mut local_file = tokio::fs::File::open(&local_path)
        .await
        .map_err(|e| format!("Cannot open local file: {e}"))?;

    sftp_session::with_sftp(|sftp| {
        Box::pin(async move {
            let mut remote_file = sftp
                .open_with_flags(
                    &remote_path,
                    OpenFlags::CREATE | OpenFlags::TRUNCATE | OpenFlags::WRITE,
                )
                .await
                .map_err(|e| format!("SFTP open for write failed: {e}"))?;

            let mut transferred: u64 = 0;
            let mut buf = vec![0u8; CHUNK_SIZE];
            let start = Instant::now();
            let mut last_report = Instant::now();

            loop {
                if cancel.load(Ordering::Relaxed) {
                    return Err("Transfer cancelled".into());
                }

                let n = local_file
                    .read(&mut buf)
                    .await
                    .map_err(|e| format!("Local read error: {e}"))?;
                if n == 0 {
                    break;
                }

                remote_file
                    .write_all(&buf[..n])
                    .await
                    .map_err(|e| format!("SFTP write error: {e}"))?;

                transferred += n as u64;

                if last_report.elapsed().as_millis() >= 100 || transferred == total {
                    report_progress(&sink, &transfer_id, &file_name, total, transferred, &start);
                    last_report = Instant::now();
                }
            }

            remote_file
                .shutdown()
                .await
                .map_err(|e| format!("SFTP close failed: {e}"))?;

            Ok(())
        })
    })
    .await
}

async fn do_download(
    transfer_id: String,
    remote_path: String,
    local_path: String,
    sink: StreamSink<TransferProgress>,
    cancel: Arc<AtomicBool>,
) -> Result<(), String> {
    let file_name = std::path::Path::new(&remote_path)
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    sftp_session::with_sftp(|sftp| {
        Box::pin(async move {
            let attrs = sftp
                .metadata(&remote_path)
                .await
                .map_err(|e| format!("SFTP stat failed: {e}"))?;
            let total = attrs.size.unwrap_or(0);

            let mut remote_file = sftp
                .open_with_flags(&remote_path, OpenFlags::READ)
                .await
                .map_err(|e| format!("SFTP open for read failed: {e}"))?;

            let mut local_file = tokio::fs::File::create(&local_path)
                .await
                .map_err(|e| format!("Cannot create local file: {e}"))?;

            let mut transferred: u64 = 0;
            let mut buf = vec![0u8; CHUNK_SIZE];
            let start = Instant::now();
            let mut last_report = Instant::now();

            loop {
                if cancel.load(Ordering::Relaxed) {
                    return Err("Transfer cancelled".into());
                }

                let n = remote_file
                    .read(&mut buf)
                    .await
                    .map_err(|e| format!("SFTP read error: {e}"))?;
                if n == 0 {
                    break;
                }

                local_file
                    .write_all(&buf[..n])
                    .await
                    .map_err(|e| format!("Local write error: {e}"))?;

                transferred += n as u64;

                if last_report.elapsed().as_millis() >= 100 || transferred >= total {
                    report_progress(&sink, &transfer_id, &file_name, total, transferred, &start);
                    last_report = Instant::now();
                }
            }

            Ok(())
        })
    })
    .await
}

fn report_progress(
    sink: &StreamSink<TransferProgress>,
    transfer_id: &str,
    file_name: &str,
    total: u64,
    transferred: u64,
    start: &Instant,
) {
    let elapsed = start.elapsed().as_secs_f64();
    let speed = if elapsed > 0.0 {
        transferred as f64 / elapsed
    } else {
        0.0
    };
    let remaining = if speed > 0.0 && total > transferred {
        (total - transferred) as f64 / speed
    } else {
        0.0
    };
    let pct = if total > 0 {
        (transferred as f64 / total as f64) * 100.0
    } else {
        100.0
    };

    let _ = sink.add(TransferProgress {
        transfer_id: transfer_id.to_string(),
        file_name: file_name.to_string(),
        total_bytes: total,
        transferred_bytes: transferred,
        percentage: pct,
        speed_bytes_per_sec: speed,
        eta_seconds: remaining,
        is_complete: transferred >= total && total > 0,
        error: String::new(),
    });
}
