//! Product-owned multi-backend Agent mux.
//!
//! The Runtime talks only to this Mahayana backend. Vendor/local adapters are
//! registered behind it. The mux owns external thread identities, operation
//! routing, approval routing, capability selection, and provider failover
//! boundaries so no presentation/runtime layer needs to know which backend is
//! serving a thread.

use crate::AgentBackend;
use crate::AgentError;
use crate::AgentEvent;
use crate::AgentEventSink;
use crate::AgentMessageRequest;
use crate::ApprovalResolution;
use crate::BackendRegistry;
use crate::McpAppSession;
use crate::OpenMcpAppRequest;
use crate::SharedAgentEventSink;
use crate::StartThreadRequest;
use async_trait::async_trait;
use mahayana_core::AgentThreadId;
use mahayana_core::ApprovalId;
use mahayana_core::OperationId;
use mahayana_core::capability::kernel::BackendCapabilities;
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Arc;
use std::sync::Mutex;

/// Adds a Mahayana-owned capability declaration to an existing adapter without
/// requiring that adapter to leak its vendor protocol into the product trait.
pub struct ProfiledBackend {
    inner: Arc<dyn AgentBackend>,
    capabilities: BackendCapabilities,
}

impl ProfiledBackend {
    pub fn new(inner: Arc<dyn AgentBackend>, capabilities: BackendCapabilities) -> Self {
        Self {
            inner,
            capabilities,
        }
    }
}

#[async_trait]
impl AgentBackend for ProfiledBackend {
    async fn start_thread(&self, request: StartThreadRequest) -> Result<AgentThreadId, AgentError> {
        self.inner.start_thread(request).await
    }

    async fn send_message(
        &self,
        request: AgentMessageRequest,
        events: SharedAgentEventSink,
    ) -> Result<(), AgentError> {
        self.inner.send_message(request, events).await
    }

    async fn interrupt(&self, operation_id: &OperationId) -> Result<(), AgentError> {
        self.inner.interrupt(operation_id).await
    }

    async fn resolve_approval(&self, resolution: ApprovalResolution) -> Result<(), AgentError> {
        self.inner.resolve_approval(resolution).await
    }

    fn capabilities(&self) -> BackendCapabilities {
        self.capabilities
    }

    async fn list_mcp_servers(&self) -> Result<Vec<Value>, AgentError> {
        self.inner.list_mcp_servers().await
    }

    async fn list_connector_apps(&self) -> Result<Vec<Value>, AgentError> {
        self.inner.list_connector_apps().await
    }

    async fn mcp_oauth_login(&self, server: &str) -> Result<String, AgentError> {
        self.inner.mcp_oauth_login(server).await
    }

    async fn mcp_oauth_logout(&self, server: &str) -> Result<bool, AgentError> {
        self.inner.mcp_oauth_logout(server).await
    }

    async fn remove_mcp_server(&self, server: &str) -> Result<bool, AgentError> {
        self.inner.remove_mcp_server(server).await
    }

    async fn mcp_custom_instructions(&self) -> Result<HashMap<String, String>, AgentError> {
        self.inner.mcp_custom_instructions().await
    }

    async fn set_mcp_custom_instructions(
        &self,
        server: &str,
        instructions: &str,
    ) -> Result<(), AgentError> {
        self.inner
            .set_mcp_custom_instructions(server, instructions)
            .await
    }

    async fn set_mcp_tool_disabled(
        &self,
        server: &str,
        tool: &str,
        disabled: bool,
    ) -> Result<Vec<String>, AgentError> {
        self.inner
            .set_mcp_tool_disabled(server, tool, disabled)
            .await
    }

    async fn refresh_mcp_servers(&self) -> Result<(), AgentError> {
        self.inner.refresh_mcp_servers().await
    }

    async fn call_mcp_tool(
        &self,
        server: &str,
        tool: &str,
        arguments: Value,
    ) -> Result<Value, AgentError> {
        self.inner.call_mcp_tool(server, tool, arguments).await
    }

    async fn open_mcp_app(&self, request: OpenMcpAppRequest) -> Result<McpAppSession, AgentError> {
        self.inner.open_mcp_app(request).await
    }

    async fn list_mcp_app_tools(
        &self,
        thread_id: &AgentThreadId,
        server: &str,
    ) -> Result<Vec<Value>, AgentError> {
        self.inner.list_mcp_app_tools(thread_id, server).await
    }

    async fn call_mcp_app_tool(
        &self,
        thread_id: &AgentThreadId,
        server: &str,
        tool: &str,
        arguments: Value,
    ) -> Result<Value, AgentError> {
        self.inner
            .call_mcp_app_tool(thread_id, server, tool, arguments)
            .await
    }

    async fn read_mcp_app_resource(
        &self,
        thread_id: &AgentThreadId,
        server: &str,
        uri: &str,
    ) -> Result<Vec<Value>, AgentError> {
        self.inner
            .read_mcp_app_resource(thread_id, server, uri)
            .await
    }

    fn name(&self) -> &'static str {
        self.inner.name()
    }
}

#[derive(Clone)]
struct ThreadRoute {
    backend: Arc<dyn AgentBackend>,
    inner_thread_id: AgentThreadId,
}

/// Runtime-facing Mahayana Agent implementation.
pub struct MahayanaMuxBackend {
    registry: BackendRegistry,
    preferred_backend: Option<String>,
    thread_routes: Mutex<HashMap<AgentThreadId, ThreadRoute>>,
    operation_routes: Arc<Mutex<HashMap<OperationId, Arc<dyn AgentBackend>>>>,
    approval_routes: Arc<Mutex<HashMap<ApprovalId, Arc<dyn AgentBackend>>>>,
}

impl MahayanaMuxBackend {
    pub fn new(preferred_backend: Option<String>) -> Self {
        Self {
            registry: BackendRegistry::default(),
            preferred_backend,
            thread_routes: Mutex::new(HashMap::new()),
            operation_routes: Arc::new(Mutex::new(HashMap::new())),
            approval_routes: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn register(
        &mut self,
        id: impl Into<String>,
        priority: i32,
        backend: Arc<dyn AgentBackend>,
    ) -> Result<(), AgentError> {
        self.registry.register(id, priority, backend)
    }

    pub fn register_profiled(
        &mut self,
        id: impl Into<String>,
        priority: i32,
        backend: Arc<dyn AgentBackend>,
        capabilities: BackendCapabilities,
    ) -> Result<(), AgentError> {
        self.registry.register(
            id,
            priority,
            Arc::new(ProfiledBackend::new(backend, capabilities)),
        )
    }

    pub fn descriptors(&self) -> Vec<crate::BackendDescriptor> {
        self.registry.descriptors()
    }

    fn default_backend(&self) -> Result<Arc<dyn AgentBackend>, AgentError> {
        if let Some(id) = self.preferred_backend.as_deref() {
            return self.registry.get(id).ok_or_else(|| {
                AgentError::Unavailable(format!("preferred Mahayana backend is unavailable: {id}"))
            });
        }
        self.registry
            .select(BackendCapabilities::default())
            .ok_or_else(|| AgentError::Unavailable("no Mahayana agent backend is registered".into()))
    }

    fn backend_for(
        &self,
        required: BackendCapabilities,
    ) -> Result<Arc<dyn AgentBackend>, AgentError> {
        if let Some(id) = self.preferred_backend.as_deref() {
            if let Some(backend) = self.registry.get(id) {
                if crate::backend_supports(backend.capabilities(), required) {
                    return Ok(backend);
                }
            }
        }
        self.registry.select(required).ok_or_else(|| {
            AgentError::Unavailable("no Mahayana backend satisfies the required capabilities".into())
        })
    }

    fn thread_route(&self, thread_id: &AgentThreadId) -> Result<ThreadRoute, AgentError> {
        self.thread_routes
            .lock()
            .map_err(|_| AgentError::Backend("Mahayana thread route lock poisoned".into()))?
            .get(thread_id)
            .cloned()
            .ok_or_else(|| AgentError::ThreadNotFound(thread_id.clone()))
    }

    fn union_capabilities(&self) -> BackendCapabilities {
        let mut union = BackendCapabilities::default();
        for descriptor in self.registry.descriptors() {
            let caps = descriptor.capabilities;
            union.realtime |= caps.realtime;
            union.tools |= caps.tools;
            union.web |= caps.web;
            union.mcp |= caps.mcp;
            union.sandbox |= caps.sandbox;
            union.subagents |= caps.subagents;
            union.checkpoints |= caps.checkpoints;
            union.headless |= caps.headless;
            union.hooks |= caps.hooks;
            union.skills |= caps.skills;
        }
        union
    }
}

struct RoutingSink {
    inner: SharedAgentEventSink,
    backend: Arc<dyn AgentBackend>,
    approval_routes: Arc<Mutex<HashMap<ApprovalId, Arc<dyn AgentBackend>>>>,
}

impl AgentEventSink for RoutingSink {
    fn emit(&self, event: AgentEvent) -> Result<(), AgentError> {
        if let AgentEvent::ApprovalRequested { approval_id, .. } = &event {
            self.approval_routes
                .lock()
                .map_err(|_| AgentError::Backend("Mahayana approval route lock poisoned".into()))?
                .insert(approval_id.clone(), Arc::clone(&self.backend));
        }
        self.inner.emit(event)
    }
}

#[async_trait]
impl AgentBackend for MahayanaMuxBackend {
    async fn start_thread(&self, request: StartThreadRequest) -> Result<AgentThreadId, AgentError> {
        let backend = self.default_backend()?;
        let inner_thread_id = backend.start_thread(request).await?;
        let public_thread_id = AgentThreadId::generated("mahayana-thread");
        self.thread_routes
            .lock()
            .map_err(|_| AgentError::Backend("Mahayana thread route lock poisoned".into()))?
            .insert(
                public_thread_id.clone(),
                ThreadRoute {
                    backend,
                    inner_thread_id,
                },
            );
        Ok(public_thread_id)
    }

    async fn send_message(
        &self,
        mut request: AgentMessageRequest,
        events: SharedAgentEventSink,
    ) -> Result<(), AgentError> {
        let route = self.thread_route(&request.thread_id)?;
        request.thread_id = route.inner_thread_id;
        self.operation_routes
            .lock()
            .map_err(|_| AgentError::Backend("Mahayana operation route lock poisoned".into()))?
            .insert(request.operation_id.clone(), Arc::clone(&route.backend));
        let sink: SharedAgentEventSink = Arc::new(RoutingSink {
            inner: events,
            backend: Arc::clone(&route.backend),
            approval_routes: Arc::clone(&self.approval_routes),
        });
        let operation_id = request.operation_id.clone();
        let result = route.backend.send_message(request, sink).await;
        if let Ok(mut routes) = self.operation_routes.lock() {
            routes.remove(&operation_id);
        }
        result
    }

    async fn interrupt(&self, operation_id: &OperationId) -> Result<(), AgentError> {
        let backend = self
            .operation_routes
            .lock()
            .map_err(|_| AgentError::Backend("Mahayana operation route lock poisoned".into()))?
            .get(operation_id)
            .cloned()
            .ok_or_else(|| AgentError::OperationNotFound(operation_id.clone()))?;
        backend.interrupt(operation_id).await
    }

    async fn resolve_approval(&self, resolution: ApprovalResolution) -> Result<(), AgentError> {
        let backend = self
            .approval_routes
            .lock()
            .map_err(|_| AgentError::Backend("Mahayana approval route lock poisoned".into()))?
            .remove(&resolution.approval_id)
            .ok_or_else(|| AgentError::ApprovalNotFound(resolution.approval_id.clone()))?;
        backend.resolve_approval(resolution).await
    }

    fn capabilities(&self) -> BackendCapabilities {
        self.union_capabilities()
    }

    async fn list_mcp_servers(&self) -> Result<Vec<Value>, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .list_mcp_servers()
        .await
    }

    async fn list_connector_apps(&self) -> Result<Vec<Value>, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .list_connector_apps()
        .await
    }

    async fn mcp_oauth_login(&self, server: &str) -> Result<String, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .mcp_oauth_login(server)
        .await
    }

    async fn mcp_oauth_logout(&self, server: &str) -> Result<bool, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .mcp_oauth_logout(server)
        .await
    }

    async fn remove_mcp_server(&self, server: &str) -> Result<bool, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .remove_mcp_server(server)
        .await
    }

    async fn mcp_custom_instructions(&self) -> Result<HashMap<String, String>, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .mcp_custom_instructions()
        .await
    }

    async fn set_mcp_custom_instructions(
        &self,
        server: &str,
        instructions: &str,
    ) -> Result<(), AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .set_mcp_custom_instructions(server, instructions)
        .await
    }

    async fn set_mcp_tool_disabled(
        &self,
        server: &str,
        tool: &str,
        disabled: bool,
    ) -> Result<Vec<String>, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .set_mcp_tool_disabled(server, tool, disabled)
        .await
    }

    async fn refresh_mcp_servers(&self) -> Result<(), AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            ..BackendCapabilities::default()
        })?
        .refresh_mcp_servers()
        .await
    }

    async fn call_mcp_tool(
        &self,
        server: &str,
        tool: &str,
        arguments: Value,
    ) -> Result<Value, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            tools: true,
            ..BackendCapabilities::default()
        })?
        .call_mcp_tool(server, tool, arguments)
        .await
    }

    async fn open_mcp_app(&self, request: OpenMcpAppRequest) -> Result<McpAppSession, AgentError> {
        self.backend_for(BackendCapabilities {
            mcp: true,
            tools: true,
            ..BackendCapabilities::default()
        })?
        .open_mcp_app(request)
        .await
    }

    async fn list_mcp_app_tools(
        &self,
        thread_id: &AgentThreadId,
        server: &str,
    ) -> Result<Vec<Value>, AgentError> {
        let route = self.thread_route(thread_id)?;
        route
            .backend
            .list_mcp_app_tools(&route.inner_thread_id, server)
            .await
    }

    async fn call_mcp_app_tool(
        &self,
        thread_id: &AgentThreadId,
        server: &str,
        tool: &str,
        arguments: Value,
    ) -> Result<Value, AgentError> {
        let route = self.thread_route(thread_id)?;
        route
            .backend
            .call_mcp_app_tool(&route.inner_thread_id, server, tool, arguments)
            .await
    }

    async fn read_mcp_app_resource(
        &self,
        thread_id: &AgentThreadId,
        server: &str,
        uri: &str,
    ) -> Result<Vec<Value>, AgentError> {
        let route = self.thread_route(thread_id)?;
        route
            .backend
            .read_mcp_app_resource(&route.inner_thread_id, server, uri)
            .await
    }

    fn name(&self) -> &'static str {
        "mahayana-mux"
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::AgentEvent;
    use crate::AgentMessageRequest;
    use async_trait::async_trait;
    use mahayana_core::ConversationId;
    use mahayana_core::Message;
    use mahayana_core::MessageId;
    use mahayana_core::MessageRole;

    struct EchoBackend(&'static str);

    #[async_trait]
    impl AgentBackend for EchoBackend {
        async fn start_thread(
            &self,
            _request: StartThreadRequest,
        ) -> Result<AgentThreadId, AgentError> {
            AgentThreadId::new(format!("{}:thread", self.0))
                .map_err(|error| AgentError::Backend(error.to_string()))
        }

        async fn send_message(
            &self,
            request: AgentMessageRequest,
            events: SharedAgentEventSink,
        ) -> Result<(), AgentError> {
            events.emit(AgentEvent::MessageCompleted {
                message: Message {
                    id: MessageId::generated("message"),
                    conversation_id: request.conversation_id,
                    role: MessageRole::Assistant,
                    text: format!("{}:{}", self.0, request.text),
                    created_at_ms: 1,
                    metadata: Value::Null,
                },
            })
        }

        async fn interrupt(&self, _operation_id: &OperationId) -> Result<(), AgentError> {
            Ok(())
        }

        async fn resolve_approval(
            &self,
            _resolution: ApprovalResolution,
        ) -> Result<(), AgentError> {
            Ok(())
        }

        fn name(&self) -> &'static str {
            self.0
        }
    }

    struct Sink(Mutex<Vec<String>>);

    impl AgentEventSink for Sink {
        fn emit(&self, event: AgentEvent) -> Result<(), AgentError> {
            if let AgentEvent::MessageCompleted { message } = event {
                self.0
                    .lock()
                    .map_err(|_| AgentError::Backend("sink lock poisoned".into()))?
                    .push(message.text);
            }
            Ok(())
        }
    }

    #[tokio::test]
    async fn runtime_sees_only_mahayana_thread_and_backend_identity() {
        let mut mux = MahayanaMuxBackend::new(Some("preferred".into()));
        mux.register_profiled(
            "fallback",
            1,
            Arc::new(EchoBackend("fallback")),
            BackendCapabilities::default(),
        )
        .expect("register fallback");
        mux.register_profiled(
            "preferred",
            10,
            Arc::new(EchoBackend("preferred")),
            BackendCapabilities {
                tools: true,
                ..BackendCapabilities::default()
            },
        )
        .expect("register preferred");

        let thread = mux
            .start_thread(StartThreadRequest {
                conversation_id: ConversationId("mahayana:agent:assistant".into()),
            })
            .await
            .expect("thread");
        assert!(thread.as_str().starts_with("mahayana-thread:"));
        let sink = Arc::new(Sink(Mutex::new(Vec::new())));
        mux.send_message(
            AgentMessageRequest {
                thread_id: thread,
                conversation_id: ConversationId("mahayana:agent:assistant".into()),
                operation_id: OperationId::generated("operation"),
                text: "hello".into(),
                client_message_id: None,
            },
            sink.clone(),
        )
        .await
        .expect("send");
        assert_eq!(sink.0.lock().expect("sink").as_slice(), ["preferred:hello"]);
        assert_eq!(mux.name(), "mahayana-mux");
    }
}
