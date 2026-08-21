from pathlib import Path
import re


def swap(path: Path, old: str, new: str, *, required: bool = True) -> None:
    text = path.read_text()
    if old in text:
        path.write_text(text.replace(old, new, 1))
        return
    if required and new not in text:
        raise SystemExit(f"{path}: guarded replacement did not match: {old[:100]!r}")


model = Path("third_party/mahayana/mahayana-rs/mahayana-model/src/lib.rs")
swap(model, "use mahayana_core::ModelProviderMode;\n", "pub use mahayana_core::ModelProviderMode;\n")

native_cargo = Path("third_party/mahayana/mahayana-rs/mahayana-native-engine/Cargo.toml")
text = native_cargo.read_text().replace("\n[dev-dependencies]\nmahayana-core.workspace = true\n", "")
native_cargo.write_text(text)

native = Path("third_party/mahayana/mahayana-rs/mahayana-native-engine/src/lib.rs")
swap(native, "use std::collections::{BTreeSet, HashMap};\n", "use std::collections::HashMap;\n")
swap(native, "    use mahayana_core::ModelProviderMode;\n", "    use mahayana_model::ModelProviderMode;\n")
swap(native, "            Capability::Network,\n", "")
swap(
    native,
    "        if self.config.enable_process_tools {\n            capabilities.push(Capability::Process);\n",
    "        if !self.model.is_local() {\n            capabilities.push(Capability::Network);\n        }\n        if self.config.enable_process_tools {\n            capabilities.push(Capability::Process);\n",
)
swap(
    native,
    "        let interrupted = self.register_operation(&request.operation_id)?;\n        let session = self.session(&request.session_id)?;\n",
    "        let session = self.session(&request.session_id)?;\n        let interrupted = self.register_operation(&request.operation_id)?;\n",
)

text = native.read_text()
pattern = re.compile(
    r"(?P<indent>\s*)scheduler\n\s*\.spawn\(\n\s*None,\n\s*name,\n\s*goal,\n\s*CapabilitySet::new\(\[Capability::Model\]\),\n\s*Value::Null,\n\s*\)\n\s*\.map_err\(\|error\| KernelError::Backend\(error\.to_string\(\)\)\)\?;\n\s*scheduler\n\s*\.start_next\(\)\n\s*\.ok_or_else\(\|\| \{\n\s*KernelError::Backend\(\"subagent concurrency exhausted\"\.into\(\)\)\n\s*\}\)\?\n\s*\.id",
    re.MULTILINE,
)
replacement = '''                        let task_id = scheduler
                            .spawn(
                                None,
                                name,
                                goal,
                                CapabilitySet::new([Capability::Model]),
                                Value::Null,
                            )
                            .map_err(|error| KernelError::Backend(error.to_string()))?;
                        scheduler
                            .start(&task_id)
                            .map_err(|error| KernelError::Backend(error.to_string()))?;
                        task_id'''
text2, count = pattern.subn(replacement, text, count=1)
if count == 0 and ".start(&task_id)" not in text:
    raise SystemExit("native engine: subagent start block did not match")
native.write_text(text2)

swap(
    native,
    '''fn safe_join(root: &Path, relative: &Path) -> Result<PathBuf, KernelError> {
    if relative.is_absolute() {
        return Err(KernelError::PolicyDenied(
            "absolute workspace paths are not allowed".into(),
        ));
    }
    let mut safe = PathBuf::from(root);
    for component in relative.components() {
        match component {
            Component::Normal(segment) => safe.push(segment),
            Component::CurDir => {}
            _ => {
                return Err(KernelError::PolicyDenied(
                    "workspace path traversal is not allowed".into(),
                ));
            }
        }
    }
    Ok(safe)
}
''',
    '''fn safe_join(root: &Path, relative: &Path) -> Result<PathBuf, KernelError> {
    if relative.is_absolute() {
        return Err(KernelError::PolicyDenied(
            "absolute workspace paths are not allowed".into(),
        ));
    }
    let canonical_root = root
        .canonicalize()
        .map_err(|error| KernelError::Backend(error.to_string()))?;
    let mut safe = canonical_root.clone();
    for component in relative.components() {
        match component {
            Component::Normal(segment) => {
                safe.push(segment);
                if safe.exists() {
                    let metadata = std::fs::symlink_metadata(&safe)
                        .map_err(|error| KernelError::Backend(error.to_string()))?;
                    if metadata.file_type().is_symlink() {
                        return Err(KernelError::PolicyDenied(format!(
                            "workspace path crosses a symbolic link: {}",
                            safe.display()
                        )));
                    }
                    let canonical = safe
                        .canonicalize()
                        .map_err(|error| KernelError::Backend(error.to_string()))?;
                    if !canonical.starts_with(&canonical_root) {
                        return Err(KernelError::PolicyDenied(
                            "workspace path escapes the active root".into(),
                        ));
                    }
                }
            }
            Component::CurDir => {}
            _ => {
                return Err(KernelError::PolicyDenied(
                    "workspace path traversal is not allowed".into(),
                ));
            }
        }
    }
    Ok(safe)
}
''',
)

orchestrator = Path("third_party/mahayana/mahayana-rs/mahayana-orchestrator/src/lib.rs")
swap(
    orchestrator,
    "    pub fn start_next(&mut self) -> Option<SubagentTask> {\n",
    '''    pub fn start(&mut self, id: &str) -> Result<SubagentTask, OrchestratorError> {
        if self.running_count() >= self.max_concurrency {
            return Err(OrchestratorError::SubagentConcurrencyExhausted);
        }
        let task = self.task_mut(id)?;
        if task.state != SubagentState::Pending {
            return Err(OrchestratorError::SubagentNotPending(id.to_string()));
        }
        task.state = SubagentState::Running;
        Ok(task.clone())
    }

    pub fn start_next(&mut self) -> Option<SubagentTask> {
''',
)
swap(
    orchestrator,
    '''    #[error("subagent is not running: {0}")]
    SubagentNotRunning(String),
}
''',
    '''    #[error("subagent is not running: {0}")]
    SubagentNotRunning(String),
    #[error("subagent is not pending: {0}")]
    SubagentNotPending(String),
    #[error("subagent concurrency is exhausted")]
    SubagentConcurrencyExhausted,
}
''',
)

workspace = Path("third_party/mahayana/mahayana-rs/mahayana-workspace-engine/src/lib.rs")
swap(workspace, "use std::collections::{BTreeMap, BTreeSet};\n", "use std::collections::BTreeSet;\n")

print("Hardened Mahayana native engine boundaries")
