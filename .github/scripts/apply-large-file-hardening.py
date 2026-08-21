#!/usr/bin/env python3
from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8')


def write(path, text):
    Path(path).write_text(text, encoding='utf-8')


def exact(path, old, new, expected=1):
    text = read(path)
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} matches, got {count}')
    write(path, text.replace(old, new))


already_hardened = (
    'dacheng-codex-local-dev-secret' not in read('ai-backend/src/server.js')
    and 'mock_alipay_user_' not in read('fabushi/web/alipay-login-functions.js')
    and "import { verifyToken } from '../../auth-utils.js';" in read('fabushi/web/src/handlers/meditation.js')
    and 'createLegacyMeditationToken' not in read('fabushi/web/src/router.js')
    and 'rust-toolchain@1.98.0' in read('.github/workflows/native-mobile.yml')
    and 'cargo install cargo-ndk --version 4.1.2 --locked' in read('.github/workflows/native-mobile.yml')
)
if already_hardened:
    print('Large-file hardening already applied; patch step is a no-op.')
    raise SystemExit(0)

exact(
    'ai-backend/src/server.js',
    "const codexAdapterSecret =\n  process.env.CODEX_DEEPSEEK_ADAPTER_SECRET ||\n  deepseekApiKey ||\n  openClawGatewayToken ||\n  'dacheng-codex-local-dev-secret';",
    "const codexAdapterSecret =\n  String(process.env.CODEX_DEEPSEEK_ADAPTER_SECRET || '').trim() ||\n  (process.env.NODE_ENV === 'production' ? '' : crypto.randomBytes(32).toString('base64url'));\nif (!codexAdapterSecret) {\n  throw new Error('CODEX_DEEPSEEK_ADAPTER_SECRET is required in production');\n}",
)
exact(
    'ai-backend/src/server.js',
    "app.set('trust proxy', Number(process.env.TRUST_PROXY_HOPS || 1));",
    "const trustProxyHops = Number(process.env.TRUST_PROXY_HOPS ?? (process.env.NODE_ENV === 'production' ? NaN : 0));\nif (!Number.isInteger(trustProxyHops) || trustProxyHops < 0 || trustProxyHops > 8) {\n  throw new Error('TRUST_PROXY_HOPS must be an integer between 0 and 8');\n}\napp.set('trust proxy', trustProxyHops);",
)

path = 'fabushi/web/alipay-login-functions.js'
text = read(path)
start = text.find("    if (!appId || !privateKey || !alipayPublicKey) {\n")
end_marker = "    // 第一步：使用auth_code换取access_token和user_id\n"
end = text.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('Alipay mock fallback markers not found')
replacement = (
    "    if (!appId || !privateKey || !alipayPublicKey) {\n"
    "      console.error('支付宝登录配置不完整，拒绝使用模拟身份');\n"
    "      return { error: true, code: 'CONFIG_MISSING', message: '支付宝登录暂不可用，请稍后再试' };\n"
    "    }\n\n"
)
write(path, text[:start] + replacement + text[end:])

path = 'fabushi/web/src/handlers/meditation.js'
exact(
    path,
    "import { jsonResponse } from '../utils/response.js';\n",
    "import { jsonResponse } from '../utils/response.js';\nimport { verifyToken } from '../../auth-utils.js';\n",
)
text = read(path)
start = text.find("// 验证认证Token并获取用户名\nasync function authenticateUser(request, db) {")
end = text.find("\nfunction asInt(value, fallback = 0) {", start)
if start < 0 or end < 0:
    raise SystemExit('Meditation auth block markers not found')
auth = (
    "// 验证认证Token并获取用户名\n"
    "async function authenticateUser(request, env, db) {\n"
    "    const authHeader = request.headers.get('Authorization');\n"
    "    if (!authHeader || !authHeader.startsWith('Bearer ')) return { error: '未授权访问', status: 401 };\n"
    "    const payload = await verifyToken(authHeader.substring(7), env);\n"
    "    if (!payload) return { error: 'Token无效或已过期', status: 401 };\n"
    "    const username = payload.username || payload.sub;\n"
    "    if (!username) return { error: '无法获取用户信息', status: 401 };\n"
    "    const tokenUserId = normalizeUserId(payload.userId ?? payload.user_id ?? payload.id);\n"
    "    const userId = tokenUserId ?? await resolveUserIdByUsername(db, username);\n"
    "    const auth = { username, userId };\n"
    "    await backfillMeditationUserId(db, auth);\n"
    "    return auth;\n"
    "}\n"
)
text = text[:start] + auth + text[end:]
calls = text.count('authenticateUser(request, db)')
if calls < 10:
    raise SystemExit(f'Unexpected meditation auth call count: {calls}')
text = text.replace('authenticateUser(request, db)', 'authenticateUser(request, env, db)')
write(path, text)

path = 'fabushi/web/src/routes/meditation-routes.js'
exact(
    path,
    "import { jsonResponse } from '../utils/response.js';\n",
    "import { jsonResponse } from '../utils/response.js';\nimport { verifyToken } from '../../auth-utils.js';\n",
)
text = read(path)
start = text.find('async function authenticateRouteUser(request, db = null) {')
end = text.find('\nfunction isMissingUserIdColumnError(error) {', start)
if start < 0 or end < 0:
    raise SystemExit('Meditation route auth block markers not found')
helper = (
    "async function authenticateRouteUser(request, env, db = null) {\n"
    "  const authHeader = request.headers.get('Authorization');\n"
    "  if (!authHeader || !authHeader.startsWith('Bearer ')) return { error: '未授权访问', status: 401 };\n"
    "  const payload = await verifyToken(authHeader.substring(7), env);\n"
    "  if (!payload) return { error: 'Token无效或已过期', status: 401 };\n"
    "  const username = payload.username || payload.sub;\n"
    "  if (!username) return { error: '无法获取用户信息', status: 401 };\n"
    "  const tokenUserId = payload.userId ?? payload.user_id ?? payload.id ?? null;\n"
    "  const userId = tokenUserId ?? (db ? await resolveUserIdByUsername(db, username) : null);\n"
    "  return { username, userId };\n"
    "}\n"
)
text = text[:start] + helper + text[end:]
if text.count('authenticateRouteUser(request, db)') != 2:
    raise SystemExit('Unexpected route auth call count')
text = text.replace('authenticateRouteUser(request, db)', 'authenticateRouteUser(request, env, db)')
text = text.replace(
    'async function handleCreateMeditationGroupWithGeneratedIds(request, db) {',
    'async function handleCreateMeditationGroupWithGeneratedIds(request, env, db) {',
)
text = text.replace(
    'handleCreateMeditationGroupWithGeneratedIds(request, db)',
    'handleCreateMeditationGroupWithGeneratedIds(request, env, db)',
)
write(path, text)

path = 'fabushi/web/src/router.js'
text = read(path)
import_line = "import { verifyToken } from '../auth-utils.js';\n"
if text.count(import_line) != 1:
    raise SystemExit('Unexpected router verifyToken import count')
text = text.replace(import_line, '')
start = text.find('function jsonStringifyAscii(value) {')
end = text.find('export async function route(request, env, db, ctx) {', start)
if start < 0 or end < 0:
    raise SystemExit('Legacy router compatibility block not found')
text = text[:start] + text[end:]
normalization = (
    "  const normalizedMeditationAuth = await normalizeMeditationAuthRequest(request, env, pathname);\n"
    "  if (normalizedMeditationAuth.response) {\n"
    "    return normalizedMeditationAuth.response;\n"
    "  }\n"
    "  request = normalizedMeditationAuth.request;\n\n"
)
if text.count(normalization) != 1:
    raise SystemExit('Legacy router normalization block not found')
text = text.replace(normalization, '')
bind = "  if (pathname === '/api/auth/bind-email' && method === 'POST') return await handleBindEmail(request, env, db);\n"
if text.count(bind) != 2:
    raise SystemExit('Unexpected duplicate bind-email route count')
text = text.replace(bind + bind, bind)
write(path, text)

path = '.github/workflows/native-mobile.yml'
text = read(path)
stable = 'uses: dtolnay/rust-toolchain@stable'
if text.count(stable) < 3:
    raise SystemExit('Unexpected Rust toolchain action count')
text = text.replace(stable, 'uses: dtolnay/rust-toolchain@1.98.0')
hash_prefix = "SOURCE_HASH: $" + "{{ hashFiles('"
if text.count(hash_prefix) != 2:
    raise SystemExit('Unexpected native source hash count')
hash_replacement = "SOURCE_HASH: $" + "{{ hashFiles('.github/workflows/native-mobile.yml', '"
text = text.replace(hash_prefix, hash_replacement)
if text.count('cargo install cargo-ndk --locked') != 1:
    raise SystemExit('Unexpected cargo-ndk install count')
text = text.replace('cargo install cargo-ndk --locked', 'cargo install cargo-ndk --version 4.1.2 --locked')
old_key = 'key: cargo-ndk-$' + '{{ runner.os }}-$' + '{{ runner.arch }}-v4'
if text.count(old_key) != 2:
    raise SystemExit('Unexpected cargo-ndk cache key count')
new_key = 'key: cargo-ndk-$' + '{{ runner.os }}-$' + '{{ runner.arch }}-v5-4.1.2'
text = text.replace(old_key, new_key)
write(path, text)

print('Large-file hardening patch applied.')
