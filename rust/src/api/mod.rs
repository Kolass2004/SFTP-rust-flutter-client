use once_cell::sync::Lazy;
use tokio::runtime::Runtime;

pub static TOKIO_RT: Lazy<Runtime> = Lazy::new(|| {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed to create Tokio runtime")
});

pub mod simple;
pub mod discovery;
pub mod sftp_session;
pub mod file_system;
pub mod transfer;
