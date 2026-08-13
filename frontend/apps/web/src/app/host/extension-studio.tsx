"use client";

import {
  Bot,
  Check,
  ChevronDown,
  ChevronUp,
  Cloud,
  Link2,
  Pencil,
  Plus,
  RefreshCw,
  Share2,
  Trash2,
  Unplug,
  Users,
  Wrench,
} from "lucide-react";
import { useMemo, useState, type FormEvent } from "react";
import type {
  BotSummary,
  ConnectorSummary,
  RuntimeCommand,
  SkillSummary,
  SkillTeamSummary,
} from "../../lib/mahayana-host/contracts";
import styles from "./host.module.css";

export type MarketplaceSection = "apps" | "connectors" | "skills" | "bots";

interface ExtensionStudioProps {
  section: Exclude<MarketplaceSection, "apps">;
  connectors: ConnectorSummary[];
  skills: SkillSummary[];
  skillTeams: SkillTeamSummary[];
  bots: BotSummary[];
  search: string;
  execute: (command: RuntimeCommand) => Promise<unknown>;
  nextRequestId: (prefix: string) => string;
  run: (action: () => Promise<unknown>) => Promise<void>;
}

const statusLabels: Record<ConnectorSummary["status"], string> = {
  connected: "已连接",
  disconnected: "未连接",
  connecting: "连接中",
  authRequired: "需要授权",
  error: "连接错误",
  disabledByTeamAdminPolicy: "团队策略已禁用",
};

function ConnectorPanel({
  connectors,
  search,
  execute,
  nextRequestId,
  run,
}: Pick<
  ExtensionStudioProps,
  "connectors" | "search" | "execute" | "nextRequestId" | "run"
>) {
  const [expanded, setExpanded] = useState<string | null>(null);
  const [accountLabels, setAccountLabels] = useState<Record<string, string>>({});
  const visible = useMemo(
    () =>
      connectors.filter((connector) =>
        `${connector.displayName} ${connector.description} ${connector.id}`
          .toLowerCase()
          .includes(search.toLowerCase()),
      ),
    [connectors, search],
  );

  return (
    <div className={styles.extensionList}>
      {visible.map((connector) => {
        const open = expanded === connector.id;
        return (
          <article className={styles.connectorCard} key={connector.id} data-status={connector.status}>
            <header>
              <span className={styles.extensionGlyph}>{connector.displayName.slice(0, 1)}</span>
              <div>
                <strong>{connector.displayName}</strong>
                <p>{connector.description}</p>
                <small>
                  {statusLabels[connector.status]}
                  {connector.accounts.length ? ` · ${connector.accounts.length} 个账户` : ""}
                  {connector.isTeam ? ` · ${connector.teammateCount ?? 0} 位队友` : ""}
                </small>
              </div>
              <button
                className={styles.extensionExpand}
                type="button"
                aria-expanded={open}
                onClick={() => setExpanded(open ? null : connector.id)}
              >
                {open ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
              </button>
            </header>
            {open ? (
              <div className={styles.connectorDetails}>
                <section>
                  <div className={styles.extensionSectionHeading}>
                    <div><Link2 size={15} /><strong>账户</strong></div>
                    {connector.canAddAccount ? (
                      <button
                        type="button"
                        onClick={() =>
                          void run(() =>
                            execute({
                              type: "connector.connect",
                              requestId: nextRequestId("connector-connect"),
                              connectorId: connector.id,
                              accountLabel: accountLabels[connector.id]?.trim() || undefined,
                            }),
                          )
                        }
                      >
                        <Plus size={14} /> 添加账户
                      </button>
                    ) : null}
                  </div>
                  {connector.canAddAccount ? (
                    <label className={styles.accountLabelDraft}>
                      <span>账户标签（可选）</span>
                      <input
                        value={accountLabels[connector.id] ?? ""}
                        onChange={(event) =>
                          setAccountLabels((current) => ({
                            ...current,
                            [connector.id]: event.target.value,
                          }))
                        }
                        placeholder="例如：工作账户"
                      />
                    </label>
                  ) : null}
                  {connector.accounts.length ? (
                    <ul className={styles.connectorAccounts}>
                      {connector.accounts.map((account) => (
                        <li key={account.id}>
                          <span data-status={account.status} />
                          <div>
                            <strong>{account.label}</strong>
                            <small>{account.email || statusLabels[account.status]}</small>
                          </div>
                          {account.teamManaged ? <em><Users size={13} /> 团队管理</em> : (
                            <>
                              <button
                                type="button"
                                aria-label={`重命名 ${account.label}`}
                                onClick={() => {
                                  const label = window.prompt("新的账户标签", account.label)?.trim();
                                  if (!label || label === account.label) return;
                                  void run(() =>
                                    execute({
                                      type: "connector.renameAccount",
                                      requestId: nextRequestId("connector-rename"),
                                      connectorId: connector.id,
                                      accountId: account.id,
                                      label,
                                    }),
                                  );
                                }}
                              >
                                <Pencil size={14} />
                              </button>
                              <button
                                type="button"
                                aria-label={`移除 ${account.label}`}
                                onClick={() =>
                                  void run(() =>
                                    execute({
                                      type: "connector.removeAccount",
                                      requestId: nextRequestId("connector-remove"),
                                      connectorId: connector.id,
                                      accountId: account.id,
                                    }),
                                  )
                                }
                              >
                                <Unplug size={14} />
                              </button>
                            </>
                          )}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className={styles.extensionEmptyInline}>尚未连接账户。</p>
                  )}
                </section>
                <section>
                  <div className={styles.extensionSectionHeading}>
                    <div><Wrench size={15} /><strong>工具</strong></div>
                    <small>{connector.tools.filter((tool) => tool.enabled).length}/{connector.tools.length} 已启用</small>
                  </div>
                  <ul className={styles.connectorTools}>
                    {connector.tools.map((tool) => (
                      <li key={tool.id}>
                        <div>
                          <strong>{tool.name}</strong>
                          <p>{tool.description}</p>
                          {tool.requiresApproval ? <small>执行写操作时需要审批</small> : null}
                        </div>
                        <input
                          className={styles.switchInput}
                          type="checkbox"
                          checked={tool.enabled}
                          onChange={(event) =>
                            void run(() =>
                              execute({
                                type: "connector.setToolEnabled",
                                requestId: nextRequestId("connector-tool"),
                                connectorId: connector.id,
                                toolId: tool.id,
                                enabled: event.target.checked,
                              }),
                            )
                          }
                        />
                      </li>
                    ))}
                  </ul>
                </section>
              </div>
            ) : null}
          </article>
        );
      })}
      {!visible.length ? <p className={styles.noResults}>没有匹配的连接器。</p> : null}
    </div>
  );
}

type SkillDraft = {
  id?: string;
  name: string;
  description: string;
  useWhen: string;
  instructions: string;
  ownerAgentId?: string;
};

const emptySkill: SkillDraft = {
  name: "",
  description: "",
  useWhen: "",
  instructions: "",
  ownerAgentId: "mahayana-assistant",
};

function SkillPanel({
  skills,
  skillTeams,
  search,
  execute,
  nextRequestId,
  run,
}: Pick<
  ExtensionStudioProps,
  "skills" | "skillTeams" | "search" | "execute" | "nextRequestId" | "run"
>) {
  const [draft, setDraft] = useState<SkillDraft>(emptySkill);
  const [editorOpen, setEditorOpen] = useState(false);
  const [publishTargets, setPublishTargets] = useState<Record<string, string>>({});
  const visible = useMemo(
    () =>
      skills.filter((skill) =>
        `${skill.name} ${skill.description} ${skill.useWhen} ${skill.teamName ?? ""}`
          .toLowerCase()
          .includes(search.toLowerCase()),
      ),
    [skills, search],
  );

  const save = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    await run(() =>
      execute({
        type: "skill.upsert",
        requestId: nextRequestId("skill-upsert"),
        id: draft.id,
        name: draft.name.trim(),
        description: draft.description.trim(),
        useWhen: draft.useWhen.trim(),
        instructions: draft.instructions,
        ownerAgentId: draft.ownerAgentId,
      }),
    );
    setDraft(emptySkill);
    setEditorOpen(false);
  };

  return (
    <div className={styles.skillStudio}>
      <div className={styles.skillToolbar}>
        <div>
          <strong>Skills</strong>
          <p>私有 Skill 仅供当前智能体使用；发布到团队后可同步共享。</p>
        </div>
        <button type="button" onClick={() => { setDraft(emptySkill); setEditorOpen(true); }}>
          <Plus size={15} /> 新建 Skill
        </button>
      </div>
      {editorOpen ? (
        <form className={styles.skillEditor} onSubmit={(event) => void save(event)}>
          <header>
            <div><strong>{draft.id ? "编辑 Skill" : "新建 Skill"}</strong><small>保存为结构化、可发布的工作流说明。</small></div>
            <button type="button" onClick={() => setEditorOpen(false)}>×</button>
          </header>
          <label><span>名称</span><input required value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} placeholder="例如：研究简报" /></label>
          <label><span>描述</span><input required value={draft.description} onChange={(event) => setDraft({ ...draft, description: event.target.value })} placeholder="一句话说明这个 Skill 的作用" /></label>
          <label><span>什么时候使用</span><textarea required rows={3} value={draft.useWhen} onChange={(event) => setDraft({ ...draft, useWhen: event.target.value })} placeholder="描述触发条件和适用场景" /></label>
          <label><span>Instructions</span><textarea required rows={8} value={draft.instructions} onChange={(event) => setDraft({ ...draft, instructions: event.target.value })} placeholder="写出可重复执行的步骤、约束和输出要求" /></label>
          <footer><button type="button" onClick={() => setEditorOpen(false)}>取消</button><button type="submit">保存 Skill</button></footer>
        </form>
      ) : null}
      <div className={styles.skillList}>
        {visible.map((skill) => {
          const teamId = publishTargets[skill.id] || skillTeams[0]?.id || "";
          return (
            <article key={skill.id} data-source={skill.source}>
              <header>
                <span className={styles.extensionGlyph}>{skill.name.slice(0, 1)}</span>
                <div>
                  <strong>{skill.name}</strong>
                  <p>{skill.description || "暂无描述"}</p>
                  <small>
                    {skill.source === "team" ? `团队 · ${skill.teamName || "Managed"}` : "私有"}
                    {` · ${skill.publishState}`}
                  </small>
                </div>
                {skill.readOnly ? <em><Users size={13} /> 管理</em> : null}
              </header>
              <section>
                <strong>Use when</strong>
                <p>{skill.useWhen}</p>
              </section>
              <footer>
                {!skill.readOnly ? (
                  <button type="button" onClick={() => { setDraft({ id: skill.id, name: skill.name, description: skill.description, useWhen: skill.useWhen, instructions: skill.instructions, ownerAgentId: skill.ownerAgentId }); setEditorOpen(true); }}><Pencil size={14} /> 编辑</button>
                ) : null}
                {skill.source === "private" && !skill.readOnly ? (
                  <>
                    <select value={teamId} onChange={(event) => setPublishTargets((current) => ({ ...current, [skill.id]: event.target.value }))}>
                      {skillTeams.map((team) => <option key={team.id} value={team.id}>{team.name}</option>)}
                    </select>
                    <button disabled={!teamId || !skill.description.trim()} type="button" onClick={() => void run(() => execute({ type: "skill.publish", requestId: nextRequestId("skill-publish"), id: skill.id, teamId }))}><Share2 size={14} /> 发布</button>
                  </>
                ) : null}
                {skill.source === "team" && skill.publishState !== "managed" ? (
                  <>
                    <button type="button" onClick={() => void run(() => execute({ type: "skill.sync", requestId: nextRequestId("skill-sync"), id: skill.id }))}><RefreshCw size={14} /> 同步</button>
                    <button type="button" onClick={() => void run(() => execute({ type: "skill.unpublish", requestId: nextRequestId("skill-unpublish"), id: skill.id }))}><Cloud size={14} /> 转为私有</button>
                  </>
                ) : null}
                {!skill.readOnly && skill.source !== "team" ? (
                  <button className={styles.dangerAction} type="button" onClick={() => void run(() => execute({ type: "skill.delete", requestId: nextRequestId("skill-delete"), id: skill.id }))}><Trash2 size={14} /> 删除</button>
                ) : null}
              </footer>
            </article>
          );
        })}
        {!visible.length ? <p className={styles.noResults}>没有匹配的 Skill。</p> : null}
      </div>
    </div>
  );
}

function BotPanel({
  bots,
  search,
  execute,
  nextRequestId,
  run,
}: Pick<
  ExtensionStudioProps,
  "bots" | "search" | "execute" | "nextRequestId" | "run"
>) {
  const visible = useMemo(
    () =>
      bots.filter((bot) =>
        `${bot.name} ${bot.description}`.toLowerCase().includes(search.toLowerCase()),
      ),
    [bots, search],
  );
  const hidden = visible.filter((bot) => bot.hidden).length;
  return (
    <div className={styles.botStudio}>
      <div className={styles.skillToolbar}>
        <div>
          <strong>Hidden Bots</strong>
          <p>隐藏 Bot 不会出现在侧边栏，但仍保留历史会话与配置。</p>
        </div>
        <span>{hidden} 个已隐藏</span>
      </div>
      <div className={styles.botList}>
        {visible.map((bot) => (
          <article key={bot.id} data-hidden={bot.hidden}>
            <span className={styles.extensionGlyph}><Bot size={18} /></span>
            <div><strong>{bot.name}</strong><p>{bot.description}</p><small>{bot.conversationId || bot.id}</small></div>
            <label>
              <span>{bot.hidden ? "已隐藏" : "显示"}</span>
              <input
                className={styles.switchInput}
                type="checkbox"
                checked={!bot.hidden}
                onChange={(event) =>
                  void run(() =>
                    execute({
                      type: "bot.setHidden",
                      requestId: nextRequestId("bot-hidden"),
                      id: bot.id,
                      hidden: !event.target.checked,
                    }),
                  )
                }
              />
            </label>
          </article>
        ))}
        {!visible.length ? <p className={styles.noResults}>没有匹配的 Bot。</p> : null}
      </div>
    </div>
  );
}

export function MarketplaceTabs({
  section,
  onChange,
  counts,
}: {
  section: MarketplaceSection;
  onChange: (section: MarketplaceSection) => void;
  counts: Record<MarketplaceSection, number>;
}) {
  const tabs: Array<[MarketplaceSection, string, React.ReactNode]> = [
    ["apps", "Apps", <Cloud size={14} key="apps" />],
    ["connectors", "Connectors", <Link2 size={14} key="connectors" />],
    ["skills", "Skills", <Wrench size={14} key="skills" />],
    ["bots", "Bots", <Bot size={14} key="bots" />],
  ];
  return (
    <nav className={styles.marketTabs} aria-label="扩展类型">
      {tabs.map(([id, label, icon]) => (
        <button type="button" className={section === id ? styles.marketTabActive : undefined} key={id} onClick={() => onChange(id)}>
          {icon}<span>{label}</span><em>{counts[id]}</em>
        </button>
      ))}
    </nav>
  );
}

export function ExtensionStudio(props: ExtensionStudioProps) {
  if (props.section === "connectors") return <ConnectorPanel {...props} />;
  if (props.section === "skills") return <SkillPanel {...props} />;
  return <BotPanel {...props} />;
}
