import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import {
  MCP_SKILLS_EXTENSION,
  miniAppSkillEntries,
  miniAppSkillGet,
  miniAppSkillsList,
} from '../src/miniapp_skills.js';

function manifest(id = 'global-dharma') {
  return {
    id,
    title: id === 'global-dharma' ? '全球法布施' : 'Example App',
    commands: [
      { name: 'status', tool: 'status', description: 'Read current status', approval: 'none' },
      { name: 'start', tool: 'start', description: 'Start execution', approval: 'required' },
    ],
  };
}

test('MiniApp Skills list exposes metadata without preloading bodies', () => {
  const payload = miniAppSkillsList(manifest());
  assert.equal(payload.extension, MCP_SKILLS_EXTENSION);
  assert.equal(payload.skills.length, 1);
  assert.match(payload.skills[0].uri, /^skill:\/\/fabushi\/global-dharma\/global-dharma-operator\/SKILL\.md$/);
  assert.equal(payload.skills[0].frontmatter.name, 'global-dharma-operator');
  assert.equal(payload.skills[0].resources.length, 1);
  assert.match(payload.skills[0].resources[0].digest, /^sha256:[a-f0-9]{64}$/);
  assert.equal('files' in payload.skills[0], false);
});

test('MiniApp Skill digest binds the exact SKILL.md bytes', () => {
  const entry = miniAppSkillEntries(manifest())[0];
  const file = entry.files[0];
  const expected = `sha256:${crypto.createHash('sha256').update(Buffer.from(file.text, 'utf8')).digest('hex')}`;
  assert.equal(entry.resources[0].digest, expected);
  assert.match(file.text, /Host approval boundary/);
  assert.match(file.text, /Global Dharma workflow/);
});

test('skills/get returns one entry and rejects unknown URIs', () => {
  const entry = miniAppSkillEntries(manifest('example-app'))[0];
  const result = miniAppSkillGet(manifest('example-app'), entry.uri);
  assert.equal(result.skill.uri, entry.uri);
  assert.equal(result.skill.frontmatter.name, 'example-app-operator');
  assert.throws(() => miniAppSkillGet(manifest('example-app'), 'skill://other/SKILL.md'), /not found/);
});

test('authored Skill metadata is normalized when a future manifest supplies skills', () => {
  const app = {
    ...manifest('example-app'),
    skills: [{
      name: 'guided-run',
      description: 'Guide the agent through a safe run.',
      markdown: '---\nname: guided-run\ndescription: Guide the agent through a safe run.\n---\n\n# Guided run',
    }],
  };
  const entry = miniAppSkillEntries(app)[0];
  assert.equal(entry.frontmatter.name, 'guided-run');
  assert.match(entry.uri, /\/guided-run\/SKILL\.md$/);
  assert.equal(entry.resources.length, 1);
});
