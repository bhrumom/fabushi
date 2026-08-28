'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');

const DESIGN_CRAFT = Object.freeze([
  'typography',
  'color',
  'accessibility-baseline',
  'animation-discipline',
  'anti-ai-slop',
]);

function ensureInside(root, candidate) {
  const base = path.resolve(root);
  const target = path.resolve(candidate);
  if (target !== base && !target.startsWith(`${base}${path.sep}`)) {
    throw new Error('Design Skill context path escapes trusted root.');
  }
  return target;
}

function wrapDesignSkillContextHandlers(baseFactory) {
  if (typeof baseFactory !== 'function') throw new TypeError('baseFactory must be a function');
  return function createDesignSkillContextHandlers(deps) {
    const base = baseFactory(deps);
    const resourcesRoot = process.resourcesPath || path.resolve(__dirname, '..', '..');
    const repoRoot = path.resolve(__dirname, '..', '..');
    const resolveBundled = (relative) => process.defaultApp
      ? path.join(repoRoot, relative)
      : path.join(resourcesRoot, relative);

    return {
      ...base,
      async getDesignSkillContext(params = {}) {
        const skillId = String(params.skillId || 'fabushi-design').trim();
        if (skillId !== 'fabushi-design') throw new Error('Only the bundled Fabushi design Skill may be activated.');

        const [designSystem, staged] = await Promise.all([
          base.getDesignSystem({ id: 'fabushi' }),
          base.stageDesignSkill({
            skillId,
            workspaceId: params.workspaceId || params.agentId || 'mahayana-assistant',
          }),
        ]);

        const stagedRoot = await fs.realpath(staged.root);
        const skillPath = ensureInside(stagedRoot, path.join(stagedRoot, 'SKILL.md'));
        const skill = await fs.readFile(skillPath, 'utf8');
        const craftRoot = resolveBundled('craft');
        const craft = [];
        for (const slug of DESIGN_CRAFT) {
          const file = ensureInside(craftRoot, path.join(craftRoot, `${slug}.md`));
          craft.push({ slug, content: await fs.readFile(file, 'utf8') });
        }

        return {
          schemaVersion: 'fabushi-design-skill-context/v1',
          skillId,
          stagedRoot,
          skill,
          craft,
          designSystem: {
            id: designSystem.manifest.id,
            design: designSystem.design,
            tokens: designSystem.tokens,
          },
          runtimeOwner: 'mahayana',
          isolated: Boolean(staged.isolated),
        };
      },
    };
  };
}

module.exports = { DESIGN_CRAFT, wrapDesignSkillContextHandlers };
