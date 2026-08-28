'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { wrapDesignSkillContextHandlers, DESIGN_CRAFT } = require('./design-skill-context.cjs');

test('trusted design Skill context returns staged Skill, Craft and canonical design data', async () => {
  const temp = await fs.mkdtemp(path.join(os.tmpdir(), 'mda-skill-context-'));
  const stagedRoot = path.join(temp, 'staged');
  await fs.mkdir(stagedRoot, { recursive: true });
  await fs.writeFile(path.join(stagedRoot, 'SKILL.md'), '# Test Skill\nUse canonical design context.');

  const factory = wrapDesignSkillContextHandlers(() => ({
    async getDesignSystem() {
      return {
        manifest: { id: 'fabushi' },
        design: '# Fabushi\n## Design',
        tokens: ':root { --fabushi-accent: #0a84ff; }',
      };
    },
    async stageDesignSkill(params) {
      assert.equal(params.skillId, 'fabushi-design');
      assert.equal(params.workspaceId, 'agent-demo');
      return { root: stagedRoot, isolated: true };
    },
  }));

  const handlers = factory({});
  const context = await handlers.getDesignSkillContext({ skillId: 'fabushi-design', workspaceId: 'agent-demo' });
  assert.equal(context.schemaVersion, 'fabushi-design-skill-context/v1');
  assert.equal(context.runtimeOwner, 'mahayana');
  assert.equal(context.isolated, true);
  assert.match(context.skill, /Test Skill/);
  assert.equal(context.designSystem.id, 'fabushi');
  assert.match(context.designSystem.tokens, /--fabushi-accent/);
  assert.deepEqual(context.craft.map((entry) => entry.slug), [...DESIGN_CRAFT]);
  assert.ok(context.craft.every((entry) => entry.content.length > 20));

  await assert.rejects(
    () => handlers.getDesignSkillContext({ skillId: '../untrusted', workspaceId: 'agent-demo' }),
    /Only the bundled Fabushi design Skill/,
  );
  await fs.rm(temp, { recursive: true, force: true });
});
