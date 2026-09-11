#!/usr/bin/env python3
"""Read-only, paginated PR integration inventory. Never merges or closes a PR."""
from __future__ import annotations

import argparse
import datetime
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request


def classify(pull: dict, checks: list[dict], parent: int | None) -> list[str]:
    blockers = []
    if pull.get('draft'):
        blockers.append('draft')
    if pull.get('base', {}).get('ref') != 'main':
        blockers.append('stacked-base' if parent else 'noncanonical-base-without-open-parent')
    if pull.get('mergeable') is not True:
        blockers.append('conflict-or-mergeability-not-confirmed')
    if not checks:
        blockers.append('no-check-evidence')
    elif any(c.get('status') != 'completed' or c.get('conclusion') != 'success' for c in checks):
        blockers.append('checks-not-all-success')
    blockers.append('protected-review-and-queue-verification-required')
    return blockers


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default=os.environ.get('GITHUB_REPOSITORY', 'bhrumom/fabushi'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repo):
        raise ValueError('invalid repository')
    token = os.environ.get('GITHUB_TOKEN', '')
    base = 'https://api.github.com/repos/' + args.repo

    def get(suffix: str):
        headers = {'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28',
                   'User-Agent': 'Fabushi-read-only-test-inventory'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = urllib.request.Request(base + suffix, headers=headers)
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    def pages(suffix: str, key: str | None = None):
        rows = []
        for page in range(1, 101):
            data = get(suffix + ('&' if '?' in suffix else '?') + f'per_page=100&page={page}')
            batch = data[key] if key else data
            rows.extend(batch)
            if len(batch) < 100:
                return rows
        raise RuntimeError('pagination safety limit exceeded; inventory incomplete')

    report = {'schema': 'fabushi.pr-inventory.v1', 'repository': args.repo,
              'observed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'status': 'incomplete', 'complete': False, 'pull_requests': [], 'merge_actions': []}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    try:
        report['canonical_main_sha'] = get('/git/ref/heads/main')['object']['sha']
        pulls = pages('/pulls?state=open&sort=updated&direction=desc')
        heads = {p['head']['ref']: p['number'] for p in pulls if p['head']['repo'] and p['head']['repo']['full_name'] == args.repo}
        for p in pulls:
            details = get('/pulls/' + str(p['number']))
            sha = details['head']['sha']
            checks = pages('/commits/' + sha + '/check-runs?filter=latest', 'check_runs')
            parent = heads.get(details['base']['ref'])
            report['pull_requests'].append({
                'number': p['number'], 'title': p['title'], 'url': p['html_url'],
                'draft': details['draft'], 'base': details['base']['ref'],
                'base_sha': details['base']['sha'], 'head': details['head']['ref'], 'head_sha': sha,
                'head_repository': details['head']['repo']['full_name'] if details['head']['repo'] else None,
                'mergeable': details['mergeable'], 'mergeable_state': details.get('mergeable_state'),
                'parent_pr': parent, 'changed_files': details['changed_files'],
                'checks': [{'name': c['name'], 'status': c['status'], 'conclusion': c['conclusion'],
                            'url': c.get('html_url')} for c in checks],
                'blockers': classify(details, checks, parent),
                'next_action': 'review exact diff, dependencies, required rules and current checks; never blind-merge',
            })
            args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        end_main = get('/git/ref/heads/main')['object']['sha']
        report.update(status='observed', complete=True, open_count=len(pulls),
                      final_main_sha=end_main, main_changed_during_inventory=end_main != report['canonical_main_sha'])
        print(f'PR_INVENTORY_OBSERVED {len(pulls)} open PRs; no merge authority inferred')
        return 0
    except (urllib.error.URLError, TimeoutError, ValueError, KeyError, RuntimeError) as error:
        report['error_type'] = type(error).__name__
        report['status'] = 'blocked'
        return 2
    finally:
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    raise SystemExit(main())
