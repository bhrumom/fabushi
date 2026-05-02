'use strict';

const FAILURE_CONCLUSIONS = new Set([
  'failure',
  'cancelled',
  'timed_out',
  'action_required',
  'startup_failure',
]);

function escapeCell(value) {
  return String(value ?? '')
    .replace(/\|/g, '\\|')
    .replace(/\r?\n/g, '<br>');
}

function formatDate(value) {
  return value ? new Date(value).toISOString() : '';
}

function bytesToHuman(value) {
  const bytes = Number(value || 0);
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  let amount = bytes;
  let unit = 0;
  while (amount >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit += 1;
  }
  return `${amount.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`;
}

function artifactUiUrl(context, artifact) {
  const { owner, repo } = context.repo;
  return `${context.serverUrl}/${owner}/${repo}/actions/runs/${context.runId}/artifacts/${artifact.id}`;
}

function isDebugArtifact(artifact) {
  return /playwright|e2e|screenshot|trace|video|diagnostic|report|patch|test-results/i.test(
    artifact.name || '',
  );
}

async function listRunJobs(github, context) {
  const { owner, repo } = context.repo;
  const response = await github.rest.actions.listJobsForWorkflowRun({
    owner,
    repo,
    run_id: context.runId,
    per_page: 100,
  });
  return response.data.jobs || [];
}

async function listRunArtifacts(github, context) {
  const { owner, repo } = context.repo;
  const response = await github.rest.actions.listWorkflowRunArtifacts({
    owner,
    repo,
    run_id: context.runId,
    per_page: 100,
  });
  return response.data.artifacts || [];
}

function renderProblemSummary(jobs, notifyJobName) {
  const relevantJobs = jobs.filter((job) => job.name !== notifyJobName);
  const problemJobs = relevantJobs.filter((job) => FAILURE_CONCLUSIONS.has(job.conclusion));

  if (problemJobs.length === 0) {
    return '- No failed job metadata was returned by the GitHub Actions API yet.';
  }

  return problemJobs
    .map((job) => `- ${job.html_url ? `[${job.name}](${job.html_url})` : job.name}: ${job.conclusion}`)
    .join('\n');
}

function renderJobRows(jobs, notifyJobName) {
  const relevantJobs = jobs.filter((job) => job.name !== notifyJobName);

  if (relevantJobs.length === 0) {
    return '| No jobs returned yet | - | - | - | - |';
  }

  return relevantJobs
    .map((job) => {
      const failedSteps = (job.steps || [])
        .filter((step) => FAILURE_CONCLUSIONS.has(step.conclusion))
        .map((step) => `${step.number}. ${step.name} (${step.conclusion})`);
      const stepSummary = failedSteps.length > 0 ? failedSteps.join('<br>') : '-';
      const jobLink = job.html_url ? `[${escapeCell(job.name)}](${job.html_url})` : escapeCell(job.name);
      return `| ${jobLink} | ${escapeCell(job.status)} | ${escapeCell(job.conclusion || 'pending')} | ${escapeCell(stepSummary)} | ${escapeCell(formatDate(job.completed_at))} |`;
    })
    .join('\n');
}

function renderArtifactRows(context, artifacts) {
  if (artifacts.length === 0) {
    return '| No artifacts returned yet | - | - | - |';
  }

  return artifacts
    .map((artifact) => {
      const name = artifact.expired
        ? `${artifact.name} (expired)`
        : `[${escapeCell(artifact.name)}](${artifactUiUrl(context, artifact)})`;
      return `| ${name} | ${escapeCell(bytesToHuman(artifact.size_in_bytes))} | ${escapeCell(formatDate(artifact.expires_at))} | ${escapeCell(artifact.id)} |`;
    })
    .join('\n');
}

function renderDebugArtifactSummary(context, artifacts) {
  const debugArtifacts = artifacts.filter(isDebugArtifact);
  if (debugArtifacts.length === 0) {
    return [
      '- No debug artifacts were found for this run yet.',
      '- If this was a Playwright failure, check whether the failing job reached the artifact upload step.',
    ].join('\n');
  }

  return debugArtifacts
    .map((artifact) => {
      const notes = [];
      if (/playwright|e2e|report/i.test(artifact.name)) {
        notes.push('HTML report / attachments');
      }
      if (/trace/i.test(artifact.name)) notes.push('trace');
      if (/video/i.test(artifact.name)) notes.push('video');
      if (/screenshot|diagnostic/i.test(artifact.name)) notes.push('screenshot/diagnostics');
      const suffix = notes.length > 0 ? ` — ${notes.join(', ')}` : '';
      return `- [${artifact.name}](${artifactUiUrl(context, artifact)})${suffix}`;
    })
    .join('\n');
}

async function ensureLabel({ github, context, core, labelName, labelColor, labelDescription }) {
  const { owner, repo } = context.repo;
  await github.rest.issues
    .createLabel({
      owner,
      repo,
      name: labelName,
      color: labelColor,
      description: labelDescription,
    })
    .catch((error) => {
      if (error.status !== 422) {
        core.warning(`Could not create ${labelName} label: ${error.message}`);
      }
    });
}

async function createOrUpdateFailureIssue({
  github,
  context,
  core,
  kind,
  titlePrefix,
  sourceSha,
  sourceRef = '',
  baseRef = '',
  prNumber = '',
  prUrl = '',
  labelName,
  labelColor,
  labelDescription,
  notifyJobName,
  extraSections = [],
}) {
  const { owner, repo } = context.repo;
  const resolvedSourceSha = sourceSha || context.sha;
  const shortSha = resolvedSourceSha.substring(0, 7);
  const runUrl = `${context.serverUrl}/${owner}/${repo}/actions/runs/${context.runId}`;
  const runAttempt = process.env.GITHUB_RUN_ATTEMPT || '';
  const runTitle = `${context.workflow} #${context.runNumber}`;
  const title = `${titlePrefix} ${shortSha}`;

  const jobs = await listRunJobs(github, context);
  const artifacts = await listRunArtifacts(github, context);
  const problemSummary = renderProblemSummary(jobs, notifyJobName);
  const jobRows = renderJobRows(jobs, notifyJobName);
  const artifactRows = renderArtifactRows(context, artifacts);
  const debugArtifactSummary = renderDebugArtifactSummary(context, artifacts);

  const body = [
    `## ${kind} failure`,
    '',
    `- Workflow run: [${runTitle}](${runUrl})`,
    `- Run ID: ${context.runId}`,
    `- Attempt: ${runAttempt}`,
    `- Trigger: ${context.eventName}`,
    `- Source SHA: ${resolvedSourceSha}`,
    sourceRef ? `- Source ref: ${sourceRef}` : null,
    baseRef ? `- Base ref: ${baseRef}` : null,
    `- Actor: @${context.actor}`,
    prNumber ? `- Pull request: [#${prNumber}](${prUrl})` : null,
    `- Updated: ${new Date().toISOString()}`,
    '',
    '### Failed or blocked jobs',
    '',
    problemSummary,
    '',
    '### Job and step details',
    '',
    '| Job | Status | Conclusion | Failed / blocked steps | Completed at |',
    '| --- | --- | --- | --- | --- |',
    jobRows,
    '',
    '### Debug artifacts',
    '',
    debugArtifactSummary,
    '',
    '### All artifacts',
    '',
    '| Artifact | Size | Expires at | Artifact ID |',
    '| --- | ---: | --- | ---: |',
    artifactRows,
    '',
    ...extraSections,
    '',
    '### Triage checklist',
    '',
    '1. Open the first failed job link above and expand the failed step.',
    '2. Open the debug artifact links for Playwright screenshots, traces, videos, or diagnostics.',
    '3. Fix the first failing step; downstream skipped jobs usually recover automatically.',
    `4. Re-run failed jobs from the workflow page: ${runUrl}`,
    '',
    '_This issue is created or updated automatically by the workflow failure notifier._',
  ].filter(Boolean).join('\n');

  await ensureLabel({ github, context, core, labelName, labelColor, labelDescription });

  const existingIssues = await github.rest.search.issuesAndPullRequests({
    q: `repo:${owner}/${repo} is:issue is:open in:title "${title}"`,
    per_page: 10,
  });
  const existing = existingIssues.data.items.find((item) => item.title === title);

  if (existing) {
    await github.rest.issues.update({
      owner,
      repo,
      issue_number: existing.number,
      body,
      labels: [labelName],
    });
    core.info(`Updated existing ${kind} failure issue #${existing.number}`);
    return existing.number;
  }

  const created = await github.rest.issues.create({
    owner,
    repo,
    title,
    body,
    labels: [labelName],
  });
  core.info(`Created ${kind} failure issue #${created.data.number}`);
  return created.data.number;
}

module.exports = { createOrUpdateFailureIssue };
