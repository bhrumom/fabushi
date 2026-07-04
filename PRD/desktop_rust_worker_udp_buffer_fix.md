# 需求与修复文档：桌面端 Rust Worker UDP 发送缓冲区不足修复

## 1. 背景与问题描述

在桌面端（macOS 等）运行全球法布施小程序时，小程序拉起的 Rust 发包 Worker (`global-dharma-worker`) 在执行全球网络节点投递时频繁出现以下报错：
```
小程序 Rust worker: udp send failed: No buffer space available (os error 55)
```
这导致 Rust 发包 Worker 异常中断并退出，进而使小程序降级到宿主系统网络进行发送，未能正常发挥高性能原生 Rust 运行时的高效发包与去发热优化作用。

### 1.1 问题剖析（第一性原理）

*   **瞬时流量过大**：全球节点多达 249 个，在 `run` 循环中，程序对每一个节点连续同步调用 `send_to`。在没有流控限制的情况下，瞬间发出几百个 UDP 报文。
*   **套接字缓冲区溢出**：操作系统网络栈中的发送缓冲区（Socket Tx Buffer / 网卡发送队列）有固定大小上限。当发包速率远远超过网卡和系统清理缓冲区的速率时，套接字便会拒绝后续发包并返回 `ENOBUFS` (os error 55，No buffer space available)。
*   **流控与退避机制缺失**：原本的 `global-dharma-worker` 源码中既没有分批休眠（流控），也未针对发送报错提供重试与等待机制，导致瞬态的拥堵变成了灾难性的进程退出。

---

## 2. 解决方案设计与实现

为了保证网络传输的高可靠性与物理发送的成功率，我们在 Rust Worker 的发包核心逻辑中实现两级优化控制：

### 2.1 全局流控 (Rate Limiting)
在 `run` 循环中引入计数器。如果是 UDP 传输通道，每发送 25 个目标节点，就强制调用 `std::thread::sleep(Duration::from_millis(10))` 进行微休眠。
*   **设计依据**：缓解操作系统的网络协议栈压力，防止网卡发送队列发生瞬时拥堵。

### 2.2 连接级退避重试 (Exponential Backoff)
在底层 `send_udp` 函数中，对每个 UDP 数据报的发送包上一层重试机制：
*   **重试触发条件**：捕获 `std::io::Error` 的 `raw_os_error()` 等于 `55` (即 `ENOBUFS`) 或 `ErrorKind::WouldBlock`。
*   **退避策略**：最多重试 5 次，初次重试前休眠 2ms，此后每次重试等待时间指数倍增 (2ms -> 4ms -> 8ms -> 16ms -> 32ms)。
*   **设计依据**：如果刚好遇到缓冲区满，稍微等待几毫秒，操作系统通常就能腾出空间发送数据，从而避免直接报错退出。

---

## 3. 修改对比说明

### 3.1 `run` 函数循环修改
```diff
+   let mut udp_count = 0;
     for endpoint in endpoints {
         emit_raw(&format!(
             "{{\"type\":\"attempting\",\"jobId\":{},\"endpointId\":{},\"transport\":{},\"at\":{}}}",
             json_quote(&job_id),
             json_quote(&endpoint.endpoint_id),
             json_quote(&endpoint.transport),
             json_quote(&now_millis_string())
         ));
         let receipt = send_to_endpoint(&endpoint, &packet_body)?;
         emit_receipt(&job_id, &receipt);
         receipts.push(receipt);
+
+        if endpoint.transport == "udp" {
+            udp_count += 1;
+            if udp_count % 25 == 0 {
+                std::thread::sleep(std::time::Duration::from_millis(10));
+            }
+        }
     }
```

### 3.2 `send_udp` 函数修改
```diff
 fn send_udp(endpoint: &Endpoint, packet_body: &str) -> Result<Receipt, String> {
     let socket =
         UdpSocket::bind(("0.0.0.0", 0)).map_err(|error| format!("udp bind failed: {error}"))?;
     if endpoint.host == "255.255.255.255" || endpoint.host.ends_with(".255") {
         socket
             .set_broadcast(true)
             .map_err(|error| format!("udp broadcast failed: {error}"))?;
     }
     let target = format!("{}:{}", endpoint.host, endpoint.port);
     let datagrams = udp_datagrams(packet_body);
     let mut sent_bytes = 0usize;
     for datagram in datagrams {
-        sent_bytes = sent_bytes.saturating_add(
-            socket
-                .send_to(datagram.as_bytes(), &target)
-                .map_err(|error| format!("udp send failed: {error}"))?,
-        );
+        let mut retries = 5;
+        let mut delay = std::time::Duration::from_millis(2);
+        loop {
+            match socket.send_to(datagram.as_bytes(), &target) {
+                Ok(bytes) => {
+                    sent_bytes = sent_bytes.saturating_add(bytes);
+                    break;
+                }
+                Err(error) => {
+                    let os_err = error.raw_os_error();
+                    if (os_err == Some(55) || error.kind() == std::io::ErrorKind::WouldBlock) && retries > 0 {
+                        retries -= 1;
+                        std::thread::sleep(delay);
+                        delay *= 2;
+                        continue;
+                    }
+                    return Err(format!("udp send failed: {error}"));
+                }
+            }
+        }
     }
```

---

## 4. 验证情况

1.  **静态检查 (`cargo check`)**：已通过，确保无语法或类型错误。
2.  **Release 构建 (`cargo build --release`)**：在工作目录顺利完成 Release 构建。
3.  **运行机制保障**：宿主系统根据小程序源码哈希自动执行构建，因此源码修改后，下次运行会自动应用最新优化程序。
