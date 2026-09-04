// ─────────────────────────────────────────────────────────────
//  Network Discovery  –  async TCP scanner for port 22
// ─────────────────────────────────────────────────────────────

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::time::Duration;
use flutter_rust_bridge::frb;
use tokio::net::TcpStream;
use tokio::time::timeout;
use crate::frb_generated::StreamSink;
use crate::api::TOKIO_RT;

/// A single discovered host on the LAN with SSH (port 22) open.
#[frb]
#[derive(Clone, Debug)]
pub struct DiscoveredHost {
    pub ip: String,
    pub port: u16,
    pub hostname: String,
    pub response_ms: u64,
}

/// Returns the local IPv4 address of this device.
#[frb(sync)]
pub fn get_local_ip() -> Option<String> {
    local_ip_address::local_ip()
        .ok()
        .map(|ip| ip.to_string())
}

/// Scan the /24 subnet of the given `base_ip` for hosts with SSH (port 22) open.
pub fn scan_network(
    base_ip: String,
    timeout_ms: u64,
    sink: StreamSink<DiscoveredHost>,
) {
    let timeout_duration = Duration::from_millis(if timeout_ms == 0 { 1500 } else { timeout_ms });

    let octets: Vec<&str> = base_ip.split('.').collect();
    if octets.len() != 4 {
        return;
    }
    let prefix = format!("{}.{}.{}", octets[0], octets[1], octets[2]);

    TOKIO_RT.spawn(async move {
        let mut handles = Vec::new();
        for i in 1u8..=254 {
            let ip_str = format!("{}.{}", prefix, i);
            let addr: SocketAddr = SocketAddr::new(
                IpAddr::V4(ip_str.parse::<Ipv4Addr>().unwrap()),
                22,
            );
            let dur = timeout_duration;
            let sink_clone = sink.clone();

            let handle = TOKIO_RT.spawn(async move {
                let start = std::time::Instant::now();
                if let Ok(Ok(_stream)) = timeout(dur, TcpStream::connect(addr)).await {
                    let elapsed = start.elapsed().as_millis() as u64;
                    let _ = sink_clone.add(DiscoveredHost {
                        ip: addr.ip().to_string(),
                        port: 22,
                        hostname: String::new(),
                        response_ms: elapsed,
                    });
                }
            });
            handles.push(handle);
        }
        for h in handles {
            let _ = h.await;
        }
    });
}

/// Probe a single IP:port to check if SSH is reachable.
pub async fn probe_host(ip: String, port: u16, timeout_ms: u64) -> Option<DiscoveredHost> {
    let addr: SocketAddr = format!("{}:{}", ip, port).parse().ok()?;
    let dur = Duration::from_millis(if timeout_ms == 0 { 1500 } else { timeout_ms });
    let start = std::time::Instant::now();
    match timeout(dur, TcpStream::connect(addr)).await {
        Ok(Ok(_)) => Some(DiscoveredHost {
            ip,
            port,
            hostname: String::new(),
            response_ms: start.elapsed().as_millis() as u64,
        }),
        _ => None,
    }
}
