export const CURSOR_CONNECTOR_SOURCE_REF = '397c8660da6d3d873a91e18c2ca2f22cac1f0ac1';
export const DEFAULT_CONNECTOR_ACCOUNT_KEY = 'default';
export const CONNECTOR_ACCOUNT_KEY_PATTERN = /^[a-z0-9][a-z0-9._-]{0,63}$/;

const cursorRepository = 'https://github.com/cursor/plugins';

const definitions = [
  ['gmail', 'Gmail', '搜索、读取、起草和管理邮件。', 'https://gmailmcp.googleapis.com/mcp/v1', 'mcp-oauth'],
  ['google-drive', 'Google Drive', '搜索、读取、创建和共享云端文件。', 'https://drivemcp.googleapis.com/mcp/v1', 'mcp-oauth'],
  ['google-calendar', 'Google Calendar', '搜索日程、查看空闲时间并安排会议。', 'https://calendarmcp.googleapis.com/mcp/v1', 'mcp-oauth'],
  ['gong', 'Gong', '读取客户、交易和通话洞察。'],
  ['salesforce', 'Salesforce', '查询、创建和更新 CRM 记录。'],
  ['playwright', 'Playwright', '使用真实浏览器导航、点击、截图和测试。'],
  ['github', 'GitHub', '管理仓库、Issue、Pull Request 和 Actions。', 'https://api.githubcopilot.com/mcp/', 'secret-ref'],
  ['ashby', 'Ashby', '搜索候选人、准备面试并管理招聘流程。'],
  ['hubspot', 'HubSpot', '搜索和更新联系人、公司、交易与工单。'],
  ['intercom', 'Intercom', '搜索会话、联系人和帮助中心内容。'],
  ['zoom', 'Zoom', '搜索会议、读取转录和 Zoom Docs。'],
  ['x', 'X', '搜索帖子、读取时间线、趋势和书签。'],
  ['clay', 'Clay', '丰富人员与公司数据并运行研究 Agent。'],
  ['circleback', 'Circleback', '搜索会议、转录、行动项和邮件。'],
  ['docusign', 'DocuSign', '管理信封、模板、工作流和协议。'],
  ['navan', 'Navan', '查询费用、差旅预订、政策和卡片。'],
  ['profound', 'Profound', '跟踪 AI 可见性、情绪与引用。'],
  ['juicebox', 'Juicebox', '查询招聘分析、候选列表和 sourcing Agent。'],
  ['outreach', 'Outreach', '搜索序列、潜客和 Kaia 会议。'],
  ['amplemarket', 'Amplemarket', '搜索人员与公司、丰富线索并运行序列。'],
  ['klaviyo', 'Klaviyo', '管理用户、细分、营销活动和自动化流程。'],
  ['customer-io', 'Customer.io', '构建营销活动、管理细分并查询用户。'],
  ['mailerlite', 'MailerLite', '管理订阅者、分组、活动和自动化。'],
  ['brevo', 'Brevo', '管理联系人、邮件/SMS 活动和 CRM 交易。'],
  ['typeform', 'Typeform', '创建表单、分析回复并管理联系人。'],
  ['jotform', 'Jotform', '创建编辑表单并读取提交。'],
  ['semrush', 'Semrush', '研究关键词、外链、流量与竞品。'],
  ['ahrefs', 'Ahrefs', '研究关键词、外链、排名与站点健康。'],
  ['godaddy', 'GoDaddy', '构思域名并检查可用性。'],
  ['upwork', 'Upwork', '搜索人才、发布职位并管理合同。'],
  ['workable', 'Workable', '搜索候选人、推进招聘流程并管理 HR 记录。'],
  ['brex', 'Brex', '查询费用、收据、账单、卡片和差旅。'],
  ['mercury', 'Mercury', '读取余额、交易、对账单和卡片。'],
  ['todoist', 'Todoist', '创建、查找并完成任务和项目。'],
  ['calendly', 'Calendly', '检查可用时间并预约、取消或改期。'],
  ['smartsheet', 'Smartsheet', '查询和更新表格、行与工作区。'],
  ['wrike', 'Wrike', '搜索项目、创建任务并发表评论。'],
  ['coda', 'Coda', '搜索文档、读取页面并更新表格。'],
  ['guru', 'Guru', '搜索公司知识并起草已验证答案。'],
  ['fireflies', 'Fireflies', '搜索会议转录、摘要和行动项。'],
  ['otter', 'Otter', '搜索会议历史并读取完整转录。'],
  ['fathom', 'Fathom', '搜索会议并读取转录和摘要。'],
  ['craft', 'Craft', '搜索、创建和更新文档与每日笔记。'],
  ['mem', 'Mem', '记录、搜索和组织笔记与集合。'],
  ['readwise', 'Readwise', '搜索高亮与 Reader 文档并保存文章。'],
  ['similarweb', 'Similarweb', '分析网站流量、受众与竞争对手。'],
  ['xero', 'Xero', '读写发票、联系人、报告和薪资数据。'],
  ['outlook', 'Outlook', '搜索、读取和发送邮件并查找联系人。'],
  ['outlook-calendar', 'Outlook Calendar', '列出、创建、更新和取消日历事件。'],
  ['onedrive', 'OneDrive', '浏览、搜索和读取文件。'],
];

function sourceUrl(id) {
  return `${cursorRepository}/tree/${CURSOR_CONNECTOR_SOURCE_REF}/third_party/${id}`;
}

function authMetadata(id, auth) {
  if (auth === 'secret-ref') {
    return {
      type: 'secret-ref',
      secretRefTemplate: `connector/${id}/{accountKey}`,
      allowedOrigins: id === 'github' ? ['https://api.githubcopilot.com'] : [],
      injection: { type: 'bearer' },
    };
  }
  if (auth === 'mcp-oauth') return { type: 'mcp-oauth' };
  return { type: 'upstream-defined' };
}

export const CONNECTOR_DEFINITIONS = definitions.map(([id, displayName, description, mcpUrl, auth]) => ({
  id,
  pluginId: `connector-${id}`,
  displayName,
  description,
  sourceUrl: sourceUrl(id),
  mcpUrl: mcpUrl || null,
  transport: mcpUrl ? 'mcp-http' : 'upstream-defined',
  auth: authMetadata(id, auth),
  accountMode: 'multi',
  defaultAccountKey: DEFAULT_CONNECTOR_ACCOUNT_KEY,
  admission: mcpUrl ? 'needs-account-auth' : 'catalog-only',
}));

const byPluginId = new Map(CONNECTOR_DEFINITIONS.map((entry) => [entry.pluginId, entry]));

export function connectorMetadataForPlugin(pluginId) {
  const entry = byPluginId.get(String(pluginId ?? '').trim().toLocaleLowerCase());
  return entry ? structuredClone(entry) : null;
}

export function connectorMarketplaceSeeds() {
  return CONNECTOR_DEFINITIONS.map((entry) => ({
    id: entry.pluginId,
    version: '1.0.0',
    title: entry.displayName,
    description: `${entry.description} 支持在同一连接器下绑定多个 Fabushi 账号槽位。`,
    publisher: {
      id: 'fabushi-connectors',
      displayName: 'Fabushi 连接器目录',
      verified: true,
      website: 'https://fabushi.ombhrum.com/apps',
    },
    categories: ['connectors', 'productivity'],
    tags: ['connector', 'mcp', 'multi-account', entry.id],
    locales: ['zh-cn', 'en'],
    homepage: entry.sourceUrl,
    featured: Boolean(entry.mcpUrl),
    bot: {
      id: `${entry.pluginId}-bot`,
      username: `${entry.pluginId.replaceAll('-', '_')}_bot`,
      displayName: entry.displayName,
      description: `通过 ${entry.displayName} 连接器使用已授权账号。`,
      managedBy: 'fabushi-connectors',
      naturalLanguage: true,
    },
    surfaces: entry.mcpUrl
      ? [
          { id: 'remote-mcp', kind: 'mcp-http', title: `${entry.displayName} MCP`, url: entry.mcpUrl, platforms: ['desktop', 'mobile', 'web', 'cli'], priority: 100 },
          { id: 'connector-docs', kind: 'web', title: '连接器说明', url: entry.sourceUrl, platforms: ['desktop', 'mobile', 'web'], priority: 10 },
        ]
      : [
          { id: 'connector-docs', kind: 'web', title: '连接器说明', url: entry.sourceUrl, platforms: ['desktop', 'mobile', 'web'], priority: 10 },
        ],
    commands: [],
    distribution: {
      installMode: 'metadata',
      repository: cursorRepository,
      sourceRef: CURSOR_CONNECTOR_SOURCE_REF,
      license: 'MIT',
    },
    permissions: ['network', 'external-account', ...(entry.auth.type === 'secret-ref' ? ['secret-store'] : [])],
    review: { state: 'approved', reviewer: 'fabushi-connector-admission', reviewedAt: 1 },
    stats: { installs: 0, monthlyActiveUsers: 0 },
    updatedAt: 1,
  }));
}
