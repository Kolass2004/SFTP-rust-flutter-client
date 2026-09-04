// ─────────────────────────────────────────────────────────────
//  SFTP Session Management  –  connect, authenticate, persist, auto-reconnect
// ─────────────────────────────────────────────────────────────

use flutter_rust_bridge::frb;
use russh::client;
use russh::keys::PublicKeyOrCertificate;
use std::sync::Arc;
use tokio::sync::Mutex;
use once_cell::sync::Lazy;
use std::time::Duration;

static SSH_SESSION: Lazy<Mutex<Option<SshState>>> = Lazy::new(|| Mutex::new(None));

// Private internal state struct not exposed to FRB
struct SshState {
    handle: client::Handle<SshHandler>,
    sftp: russh_sftp::client::SftpSession,
    host: String,
    port: u16,
    user: String,
    password: String,
}

// Handler implementation
struct SshHandler {}

impl client::Handler for SshHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &PublicKeyOrCertificate,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }
}

// ── Public API ──────────────────────────────────────────────

/// Result type returned to Dart after a connection attempt.
#[frb]
#[derive(Clone, Debug)]
pub struct ConnectResult {
    pub success: bool,
    pub message: String,
    pub home_dir: String,
}

/// Connect to an SSH/SFTP server with username + password.
pub async fn connect_sftp(
    host: String,
    port: u16,
    username: String,
    password: String,
) -> ConnectResult {
    let mut config = client::Config::default();
    config.inactivity_timeout = None;
    config.keepalive_interval = Some(Duration::from_secs(10));
    config.keepalive_max = 5;

    let config_arc = Arc::new(config);
    let addr = format!("{}:{}", host, port);

    // 1. TCP + SSH handshake
    let mut handle = match client::connect(config_arc, &*addr, SshHandler {}).await {
        Ok(h) => h,
        Err(e) => {
            return ConnectResult {
                success: false,
                message: format!("SSH connect failed: {e}"),
                home_dir: String::new(),
            };
        }
    };

    // 2. Authenticate
    match handle.authenticate_password(&username, &password).await {
        Ok(russh::client::AuthResult::Success) => {}
        Ok(_) => {
            return ConnectResult {
                success: false,
                message: "Authentication rejected".into(),
                home_dir: String::new(),
            };
        }
        Err(e) => {
            return ConnectResult {
                success: false,
                message: format!("Auth error: {e}"),
                home_dir: String::new(),
            };
        }
    }

    // 3. Open SFTP subsystem
    let channel = match handle.channel_open_session().await {
        Ok(c) => c,
        Err(e) => {
            return ConnectResult {
                success: false,
                message: format!("Channel open failed: {e}"),
                home_dir: String::new(),
            };
        }
    };

    if let Err(e) = channel.request_subsystem(true, "sftp").await {
        return ConnectResult {
            success: false,
            message: format!("SFTP subsystem request failed: {e}"),
            home_dir: String::new(),
        };
    }

    let sftp = match russh_sftp::client::SftpSession::new(channel.into_stream()).await {
        Ok(s) => s,
        Err(e) => {
            return ConnectResult {
                success: false,
                message: format!("SFTP session init failed: {e}"),
                home_dir: String::new(),
            };
        }
    };

    // 4. Resolve home directory
    let home = sftp.canonicalize(".").await.unwrap_or_else(|_| "/".into());

    // 5. Store globally
    let mut lock = SSH_SESSION.lock().await;
    *lock = Some(SshState {
        handle,
        sftp,
        host: host.clone(),
        port,
        user: username.clone(),
        password: password.clone(),
    });

    ConnectResult {
        success: true,
        message: format!("Connected to {} as {}", host, username),
        home_dir: home,
    }
}

/// Disconnect from the current server.
pub async fn disconnect_sftp() -> bool {
    let mut lock = SSH_SESSION.lock().await;
    if let Some(state) = lock.take() {
        let _ = state.sftp.close().await;
        let _ = state
            .handle
            .disconnect(russh::Disconnect::ByApplication, "user disconnect", "en")
            .await;
        true
    } else {
        false
    }
}

/// Check if we are currently connected.
#[frb(sync)]
pub fn is_connected() -> bool {
    SSH_SESSION
        .try_lock()
        .map(|g| g.is_some())
        .unwrap_or(false)
}

/// Ping active SFTP session to keep connection alive.
pub async fn ping_sftp() -> bool {
    with_sftp(|sftp| {
        Box::pin(async move {
            sftp.canonicalize(".").await.map_err(|e| e.to_string())?;
            Ok(())
        })
    })
    .await
    .is_ok()
}

// ── Internal helper for other Rust modules with Auto-Reconnect ──

pub(crate) async fn with_sftp<F, R>(f: F) -> Result<R, String>
where
    F: FnOnce(&russh_sftp::client::SftpSession) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<R, String>> + Send + '_>>,
{
    let mut lock = SSH_SESSION.lock().await;

    // Check if session exists and is alive
    let is_alive = match lock.as_ref() {
        Some(state) => state.sftp.canonicalize(".").await.is_ok(),
        None => false,
    };

    if !is_alive {
        // Attempt transparent auto-reconnect
        let params = lock.as_ref().map(|s| (s.host.clone(), s.port, s.user.clone(), s.password.clone()));
        drop(lock);

        if let Some((host, port, user, password)) = params {
            let res = connect_sftp(host, port, user, password).await;
            if !res.success {
                return Err(format!("SFTP reconnect failed: {}", res.message));
            }
        } else {
            return Err("Not connected to SFTP server".into());
        }

        lock = SSH_SESSION.lock().await;
    }

    if let Some(state) = lock.as_ref() {
        f(&state.sftp).await
    } else {
        Err("SFTP session unavailable".into())
    }
}
