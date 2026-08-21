from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1))


model = Path("third_party/mahayana/mahayana-rs/mahayana-model/src/lib.rs")
replace_once(
    model,
    "use mahayana_core::ModelProviderMode;\n",
    "pub use mahayana_core::ModelProviderMode;\n",
)

native_cargo = Path("third_party/mahayana/mahayana-rs/mahayana-native-engine/Cargo.toml")
text = native_cargo.read_text()
text = text.replace("\n[dev-dependencies]\nmahayana-core.workspace = true\n", "")
native_cargo.write_text(text)

native = Path("third_party/mahayana/mahayana-rs/mahayana-native-engine/src/lib.rs")
replace_once(
    native,
    "use std::collections::{BTreeSet, HashMap};\n",
    "use std::collections::HashMap;\n",
)
replace_once(
    native,
    "    use mahayana_core::ModelProviderMode;\n",
    "    use mahayana_model::ModelProviderMode;\n",
)
replace_once(
    native,
    '''            Capability::Model,\n            Capability::Network,\n            Capability::FilesystemRead,\n''',
    '''            Capability::Model,\n            Capability::FilesystemRead,\n''',
)
replace_once(
    native,
    '''        if self.config.enable_process_tools {\n            capabilities.push(Capability::Process);\n            capabilities.push(Capability::Git);\n        }\n        CapabilitySet::new(capabilities)\n''',
    '''        if !self.model.is_local() {\n            capabilities.push(Capability::Network);\n        }\n        if self.config.enable_process_tools {\n            capabilities.push(Capability::Process);\n            capabilities.push(Capability::Git);\n        }\n        CapabilitySet::new(capabilities)\n''',
)
replace_once(
    native,
    '''        let interrupted = self.register_operation(&request.operation_id)?;\n        let session = self.session(&request.session_id)?;\n''',
    '''        let session = self.session(&request.session_id)?;\n        let interrupted = self.register_operation(&request.operation_id)?;\n''',
)
replace_once(
    native,
    '''                        scheduler\n                            .spawn(\n                                None,\n                                name,\n                                goal,\n                                CapabilitySet::new([Capability::Model]),\n                                Value::Null,\n                            )\n                            .map_err(|error| KernelError::Backend(error.to_string()))?;\n                        scheduler\n                            .start_next()\n                            .ok_or_else(|| KernelError::Backend("subagent concurrency exhausted".into()))?\n                            .id\n''',
    '''                        let task_id = scheduler\n                            .spawn(\n                                None,\n                                name,\n                                goal,\n                                CapabilitySet::new([Capability::Model]),\n                                Value::Null,\n                            )\n                            .map_err(|error| KernelError::Backend(error.to_string()))?;\n                        scheduler\n                            .start(&task_id)\n                            .map_err(|error| KernelError::Backend(error.to_string()))?;\n                        task_id\n''',
)
replace_once(
    native,
    '''fn safe_join(root: &Path, relative: &Path) -> Result<PathBuf, KernelError> {\n    if relative.is_absolute() {\n        return Err(KernelError::PolicyDenied(\n            "absolute workspace paths are not allowed".into(),\n        ));\n    }\n    let mut safe = PathBuf::from(root);\n    for component in relative.components() {\n        match component {\n            Component::Normal(segment) => safe.push(segment),\n            Component::CurDir => {}\n            _ => {\n                return Err(KernelError::PolicyDenied(\n                    "workspace path traversal is not allowed".into(),\n                ));\n            }\n        }\n    }\n    Ok(safe)\n}\n''',
    '''fn safe_join(root: &Path, relative: &Path) -> Result<PathBuf, KernelError> {\n    if relative.is_absolute() {\n        return Err(KernelError::PolicyDenied(\n            "absolute workspace paths are not allowed".into(),\n        ));\n    }\n    let canonical_root = root\n        .canonicalize()\n        .map_err(|error| KernelError::Backend(error.to_string()))?;\n    let mut safe = canonical_root.clone();\n    for component in relative.components() {\n        match component {\n            Component::Normal(segment) => {\n                safe.push(segment);\n                if safe.exists() {\n                    let metadata = std::fs::symlink_metadata(&safe)\n                        .map_err(|error| KernelError::Backend(error.to_string()))?;\n                    if metadata.file_type().is_symlink() {\n                        return Err(KernelError::PolicyDenied(format!(\n                            "workspace path crosses a symbolic link: {}",\n                            safe.display()\n                        )));\n                    }\n                    let canonical = safe\n                        .canonicalize()\n                        .map_err(|error| KernelError::Backend(error.to_string()))?;\n                    if !canonical.starts_with(&canonical_root) {\n                        return Err(KernelError::PolicyDenied(\n                            "workspace path escapes the active root".into(),\n                        ));\n                    }\n                }\n            }\n            Component::CurDir => {}\n            _ => {\n                return Err(KernelError::PolicyDenied(\n                    "workspace path traversal is not allowed".into(),\n                ));\n            }\n        }\n    }\n    Ok(safe)\n}\n''',
)

orchestrator = Path("third_party/mahayana/mahayana-rs/mahayana-orchestrator/src/lib.rs")
replace_once(
    orchestrator,
    '''    pub fn start_next(&mut self) -> Option<SubagentTask> {\n''',
    '''    pub fn start(&mut self, id: &str) -> Result<SubagentTask, OrchestratorError> {\n        if self.running_count() >= self.max_concurrency {\n            return Err(OrchestratorError::SubagentConcurrencyExhausted);\n        }\n        let task = self.task_mut(id)?;\n        if task.state != SubagentState::Pending {\n            return Err(OrchestratorError::SubagentNotPending(id.to_string()));\n        }\n        task.state = SubagentState::Running;\n        Ok(task.clone())\n    }\n\n    pub fn start_next(&mut self) -> Option<SubagentTask> {\n''',
)
replace_once(
    orchestrator,
    '''    #[error("subagent is not running: {0}")]\n    SubagentNotRunning(String),\n}\n''',
    '''    #[error("subagent is not running: {0}")]\n    SubagentNotRunning(String),\n    #[error("subagent is not pending: {0}")]\n    SubagentNotPending(String),\n    #[error("subagent concurrency is exhausted")]\n    SubagentConcurrencyExhausted,\n}\n''',
)

workspace = Path("third_party/mahayana/mahayana-rs/mahayana-workspace-engine/src/lib.rs")
replace_once(
    workspace,
    "use std::collections::{BTreeMap, BTreeSet};\n",
    "use std::collections::BTreeSet;\n",
)

print("Hardened Mahayana native engine, orchestrator, and workspace boundaries")
