use anyhow::{anyhow, Result};
use async_trait::async_trait;
use futures::stream::{BoxStream, StreamExt};
use tokio::sync::mpsc::{self, Receiver, Sender};
use tokio_stream::wrappers::ReceiverStream;

/// 通用连接驱动接口：赋予 codex rust sdk 跨平台底层通讯调用能力
#[async_trait]
pub trait CodexTransport: Send + Sync {
    /// 向 Codex 引擎发送协议请求或工作指令
    async fn send_message(&mut self, payload: String) -> Result<()>;
    /// 接收 Codex 引擎返回的实时流式分片
    async fn receive_stream(&mut self) -> Result<BoxStream<'static, Result<String>>>;
    /// 终止当前连接或会话
    async fn terminate(&mut self) -> Result<()>;
}

/// 内存/虚拟测试通道驱动：可在任意平台运行，用于沙盒与移动端内嵌调用
pub struct InProcessMemoryTransport {
    tx: Sender<String>,
    rx: Option<Receiver<String>>,
    active: bool,
}

impl InProcessMemoryTransport {
    pub fn new() -> (Self, Sender<String>, Receiver<String>) {
        let (tx_out, rx_out) = mpsc::channel(100);
        let (tx_in, rx_in) = mpsc::channel(100);
        (
            Self {
                tx: tx_out,
                rx: Some(rx_in),
                active: true,
            },
            tx_in,
            rx_out,
        )
    }
}

#[async_trait]
impl CodexTransport for InProcessMemoryTransport {
    async fn send_message(&mut self, payload: String) -> Result<()> {
        if !self.active {
            return Err(anyhow!("Transport is terminated"));
        }
        self.tx
            .send(payload)
            .await
            .map_err(|e| anyhow!("Failed to send message: {}", e))
    }

    async fn receive_stream(&mut self) -> Result<BoxStream<'static, Result<String>>> {
        let rx = self
            .rx
            .take()
            .ok_or_else(|| anyhow!("Receive stream already taken"))?;
        let stream = ReceiverStream::new(rx).map(Ok);
        Ok(Box::pin(stream))
    }

    async fn terminate(&mut self) -> Result<()> {
        self.active = false;
        Ok(())
    }
}

#[cfg(feature = "transport-subprocess")]
#[allow(dead_code)]
pub struct SubprocessTransport {
    command_path: String,
    args: Vec<String>,
    active: bool,
    tx: Option<Sender<String>>,
    rx: Option<Receiver<String>>,
}

#[cfg(feature = "transport-subprocess")]
impl SubprocessTransport {
    pub fn new(command_path: impl Into<String>, args: Vec<String>) -> Self {
        let (tx, rx_in) = mpsc::channel(100);
        Self {
            command_path: command_path.into(),
            args,
            active: true,
            tx: Some(tx),
            rx: Some(rx_in),
        }
    }
}

#[cfg(feature = "transport-subprocess")]
#[async_trait]
impl CodexTransport for SubprocessTransport {
    async fn send_message(&mut self, payload: String) -> Result<()> {
        if !self.active {
            return Err(anyhow!("Subprocess transport is terminated"));
        }
        if let Some(tx) = &self.tx {
            tx.send(payload)
                .await
                .map_err(|e| anyhow!("Failed to send to subprocess pipe: {}", e))?;
        }
        Ok(())
    }

    async fn receive_stream(&mut self) -> Result<BoxStream<'static, Result<String>>> {
        let rx = self
            .rx
            .take()
            .ok_or_else(|| anyhow!("Subprocess receive stream already taken"))?;
        let stream = ReceiverStream::new(rx).map(Ok);
        Ok(Box::pin(stream))
    }

    async fn terminate(&mut self) -> Result<()> {
        self.active = false;
        self.tx = None;
        Ok(())
    }
}
