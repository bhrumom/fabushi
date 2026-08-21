//! Mahayana goal graph and objective verifier.
//!
//! Long-running work is decomposed into independently verifiable nodes. The
//! graph is product state; subagents/backends execute ready nodes but cannot
//! mark a goal complete without its required objective oracles passing.

use crate::capability::kernel::OracleStatus;
use crate::capability::kernel::VerificationOracle;
use serde::Deserialize;
use serde::Serialize;
use std::collections::BTreeMap;
use std::collections::BTreeSet;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum GoalNodeState {
    Pending,
    Ready,
    Running,
    Paused,
    Verifying,
    Succeeded,
    Failed,
    Cancelled,
    Blocked,
}

impl GoalNodeState {
    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Succeeded | Self::Failed | Self::Cancelled)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GoalNode {
    pub id: String,
    pub title: String,
    pub objective: String,
    pub dependencies: Vec<String>,
    pub state: GoalNodeState,
    pub assigned_agent: Option<String>,
    pub oracles: Vec<VerificationOracle>,
}

impl GoalNode {
    pub fn new(
        id: impl Into<String>,
        title: impl Into<String>,
        objective: impl Into<String>,
        dependencies: Vec<String>,
        oracles: Vec<VerificationOracle>,
    ) -> Result<Self, GoalError> {
        let id = id.into();
        let title = title.into();
        let objective = objective.into();
        if id.trim().is_empty() {
            return Err(GoalError::EmptyField("goalNode.id"));
        }
        if title.trim().is_empty() {
            return Err(GoalError::EmptyField("goalNode.title"));
        }
        if objective.trim().is_empty() {
            return Err(GoalError::EmptyField("goalNode.objective"));
        }
        if !oracles.iter().any(|oracle| oracle.required && oracle.objective) {
            return Err(GoalError::ObjectiveOracleRequired(id));
        }
        Ok(Self {
            id,
            title,
            objective,
            dependencies,
            state: GoalNodeState::Pending,
            assigned_agent: None,
            oracles,
        })
    }

    pub fn verification_ready(&self) -> Result<(), GoalError> {
        for oracle in self.oracles.iter().filter(|oracle| oracle.required) {
            match oracle.status {
                OracleStatus::Passed => {}
                OracleStatus::Failed => {
                    return Err(GoalError::OracleFailed {
                        node: self.id.clone(),
                        oracle: oracle.name.clone(),
                    });
                }
                OracleStatus::Pending | OracleStatus::Skipped => {
                    return Err(GoalError::OracleIncomplete {
                        node: self.id.clone(),
                        oracle: oracle.name.clone(),
                    });
                }
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GoalGraph {
    pub id: String,
    pub objective: String,
    nodes: BTreeMap<String, GoalNode>,
}

impl GoalGraph {
    pub fn new(id: impl Into<String>, objective: impl Into<String>) -> Result<Self, GoalError> {
        let id = id.into();
        let objective = objective.into();
        if id.trim().is_empty() {
            return Err(GoalError::EmptyField("goal.id"));
        }
        if objective.trim().is_empty() {
            return Err(GoalError::EmptyField("goal.objective"));
        }
        Ok(Self {
            id,
            objective,
            nodes: BTreeMap::new(),
        })
    }

    pub fn add_node(&mut self, node: GoalNode) -> Result<(), GoalError> {
        if self.nodes.contains_key(&node.id) {
            return Err(GoalError::DuplicateNode(node.id));
        }
        self.nodes.insert(node.id.clone(), node);
        self.validate_dependencies()?;
        self.refresh_ready_states();
        Ok(())
    }

    pub fn node(&self, id: &str) -> Option<&GoalNode> {
        self.nodes.get(id)
    }

    pub fn nodes(&self) -> Vec<&GoalNode> {
        self.nodes.values().collect()
    }

    pub fn ready_nodes(&self) -> Vec<&GoalNode> {
        self.nodes
            .values()
            .filter(|node| node.state == GoalNodeState::Ready)
            .collect()
    }

    pub fn assign(&mut self, node_id: &str, agent_id: impl Into<String>) -> Result<(), GoalError> {
        let node = self.node_mut(node_id)?;
        if node.state != GoalNodeState::Ready && node.state != GoalNodeState::Paused {
            return Err(GoalError::NodeNotRunnable(node_id.to_string()));
        }
        let agent_id = agent_id.into();
        if agent_id.trim().is_empty() {
            return Err(GoalError::EmptyField("assignedAgent"));
        }
        node.assigned_agent = Some(agent_id);
        node.state = GoalNodeState::Running;
        Ok(())
    }

    pub fn pause(&mut self, node_id: &str) -> Result<(), GoalError> {
        let node = self.node_mut(node_id)?;
        if node.state != GoalNodeState::Running {
            return Err(GoalError::InvalidTransition {
                node: node_id.to_string(),
                from: node.state,
                to: GoalNodeState::Paused,
            });
        }
        node.state = GoalNodeState::Paused;
        Ok(())
    }

    pub fn begin_verification(&mut self, node_id: &str) -> Result<(), GoalError> {
        let node = self.node_mut(node_id)?;
        if node.state != GoalNodeState::Running {
            return Err(GoalError::InvalidTransition {
                node: node_id.to_string(),
                from: node.state,
                to: GoalNodeState::Verifying,
            });
        }
        node.state = GoalNodeState::Verifying;
        Ok(())
    }

    pub fn record_oracle(
        &mut self,
        node_id: &str,
        oracle_name: &str,
        status: OracleStatus,
        evidence: Option<String>,
    ) -> Result<(), GoalError> {
        let node = self.node_mut(node_id)?;
        let oracle = node
            .oracles
            .iter_mut()
            .find(|oracle| oracle.name == oracle_name)
            .ok_or_else(|| GoalError::OracleNotFound {
                node: node_id.to_string(),
                oracle: oracle_name.to_string(),
            })?;
        oracle.status = status;
        oracle.evidence = evidence;
        Ok(())
    }

    pub fn complete_node(&mut self, node_id: &str) -> Result<(), GoalError> {
        {
            let node = self.node_mut(node_id)?;
            if node.state != GoalNodeState::Verifying {
                return Err(GoalError::InvalidTransition {
                    node: node_id.to_string(),
                    from: node.state,
                    to: GoalNodeState::Succeeded,
                });
            }
            node.verification_ready()?;
            node.state = GoalNodeState::Succeeded;
        }
        self.refresh_ready_states();
        Ok(())
    }

    pub fn fail_node(&mut self, node_id: &str) -> Result<(), GoalError> {
        let node = self.node_mut(node_id)?;
        if !matches!(node.state, GoalNodeState::Running | GoalNodeState::Verifying) {
            return Err(GoalError::InvalidTransition {
                node: node_id.to_string(),
                from: node.state,
                to: GoalNodeState::Failed,
            });
        }
        node.state = GoalNodeState::Failed;
        self.refresh_ready_states();
        Ok(())
    }

    pub fn is_complete(&self) -> bool {
        !self.nodes.is_empty()
            && self
                .nodes
                .values()
                .all(|node| node.state == GoalNodeState::Succeeded)
    }

    pub fn progress(&self) -> (usize, usize) {
        let total = self.nodes.len();
        let succeeded = self
            .nodes
            .values()
            .filter(|node| node.state == GoalNodeState::Succeeded)
            .count();
        (succeeded, total)
    }

    fn node_mut(&mut self, id: &str) -> Result<&mut GoalNode, GoalError> {
        self.nodes
            .get_mut(id)
            .ok_or_else(|| GoalError::NodeNotFound(id.to_string()))
    }

    fn validate_dependencies(&self) -> Result<(), GoalError> {
        for node in self.nodes.values() {
            for dependency in &node.dependencies {
                if dependency == &node.id {
                    return Err(GoalError::DependencyCycle(node.id.clone()));
                }
                if !self.nodes.contains_key(dependency) {
                    return Err(GoalError::DependencyNotFound {
                        node: node.id.clone(),
                        dependency: dependency.clone(),
                    });
                }
            }
        }
        for node in self.nodes.keys() {
            let mut visiting = BTreeSet::new();
            let mut visited = BTreeSet::new();
            self.visit(node, &mut visiting, &mut visited)?;
        }
        Ok(())
    }

    fn visit(
        &self,
        node_id: &str,
        visiting: &mut BTreeSet<String>,
        visited: &mut BTreeSet<String>,
    ) -> Result<(), GoalError> {
        if visited.contains(node_id) {
            return Ok(());
        }
        if !visiting.insert(node_id.to_string()) {
            return Err(GoalError::DependencyCycle(node_id.to_string()));
        }
        let node = self
            .nodes
            .get(node_id)
            .ok_or_else(|| GoalError::NodeNotFound(node_id.to_string()))?;
        for dependency in &node.dependencies {
            self.visit(dependency, visiting, visited)?;
        }
        visiting.remove(node_id);
        visited.insert(node_id.to_string());
        Ok(())
    }

    fn refresh_ready_states(&mut self) {
        let states = self
            .nodes
            .iter()
            .map(|(id, node)| (id.clone(), node.state))
            .collect::<BTreeMap<_, _>>();
        for node in self.nodes.values_mut() {
            if matches!(node.state, GoalNodeState::Pending | GoalNodeState::Ready) {
                let failed_dependency = node.dependencies.iter().any(|dependency| {
                    matches!(
                        states.get(dependency),
                        Some(GoalNodeState::Failed | GoalNodeState::Cancelled | GoalNodeState::Blocked)
                    )
                });
                if failed_dependency {
                    node.state = GoalNodeState::Blocked;
                    continue;
                }
                let ready = node.dependencies.iter().all(|dependency| {
                    states.get(dependency) == Some(&GoalNodeState::Succeeded)
                });
                node.state = if ready {
                    GoalNodeState::Ready
                } else {
                    GoalNodeState::Pending
                };
            }
        }
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum GoalError {
    #[error("field must not be empty: {0}")]
    EmptyField(&'static str),
    #[error("goal node requires an objective verification oracle: {0}")]
    ObjectiveOracleRequired(String),
    #[error("duplicate goal node: {0}")]
    DuplicateNode(String),
    #[error("goal node was not found: {0}")]
    NodeNotFound(String),
    #[error("goal node is not runnable: {0}")]
    NodeNotRunnable(String),
    #[error("dependency was not found for {node}: {dependency}")]
    DependencyNotFound { node: String, dependency: String },
    #[error("goal dependency cycle detected at: {0}")]
    DependencyCycle(String),
    #[error("invalid goal transition for {node}: {from:?} -> {to:?}")]
    InvalidTransition {
        node: String,
        from: GoalNodeState,
        to: GoalNodeState,
    },
    #[error("verification oracle was not found for {node}: {oracle}")]
    OracleNotFound { node: String, oracle: String },
    #[error("required oracle is incomplete for {node}: {oracle}")]
    OracleIncomplete { node: String, oracle: String },
    #[error("required oracle failed for {node}: {oracle}")]
    OracleFailed { node: String, oracle: String },
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capability::kernel::VerificationKind;

    fn oracle(name: &str) -> VerificationOracle {
        VerificationOracle::new(name, VerificationKind::CiCheck, true, true).expect("oracle")
    }

    #[test]
    fn dependencies_unlock_only_after_objective_verification() {
        let mut graph = GoalGraph::new("G1", "ship product").expect("graph");
        graph
            .add_node(GoalNode::new("T1", "kernel", "build kernel", vec![], vec![oracle("ci")]).expect("node"))
            .expect("add");
        graph
            .add_node(
                GoalNode::new(
                    "T2",
                    "surface",
                    "wire surface",
                    vec!["T1".into()],
                    vec![oracle("e2e")],
                )
                .expect("node"),
            )
            .expect("add");
        assert_eq!(graph.ready_nodes().iter().map(|node| node.id.as_str()).collect::<Vec<_>>(), vec!["T1"]);
        graph.assign("T1", "agent:1").expect("assign");
        graph.begin_verification("T1").expect("verify");
        assert!(graph.complete_node("T1").is_err());
        graph.record_oracle("T1", "ci", OracleStatus::Passed, Some("run:1".into())).expect("oracle");
        graph.complete_node("T1").expect("complete");
        assert_eq!(graph.ready_nodes().iter().map(|node| node.id.as_str()).collect::<Vec<_>>(), vec!["T2"]);
    }

    #[test]
    fn cycle_is_rejected() {
        let mut graph = GoalGraph::new("G1", "ship").expect("graph");
        graph
            .add_node(GoalNode::new("T1", "one", "one", vec![], vec![oracle("ci")]).expect("node"))
            .expect("add");
        let result = graph.add_node(
            GoalNode::new("T2", "two", "two", vec!["missing".into()], vec![oracle("ci")]).expect("node"),
        );
        assert!(matches!(result, Err(GoalError::DependencyNotFound { .. })));
    }
}
