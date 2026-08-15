const __mod=require('node:module');const __p=require('node:path');const __depsDir=__p.join(__dirname,'..','deps');process.env.NODE_PATH=__depsDir+(process.env.NODE_PATH?__p.delimiter+process.env.NODE_PATH:'');__mod.Module._initPaths();const __import_meta_url=require('node:url').pathToFileURL(__filename).href;
"use strict";var h=require("node:worker_threads");var T=class extends Error{constructor(e){super(e),this.name="SandInvariantViolation"}},$=null;var Y="Invariant violation (message stripped in packaged builds; the stack identifies the site)";function z(){return!0}var J=/^at /,Q=/^at (?:new SandInvariantViolation\b|invariant\b|installInvariantReporter\b)/;function Z(t){let e=t.stack;if(e==null||!e.startsWith(_(t)))return null;for(let n of e.slice(_(t).length).split(`
`)){let r=n.trim();if(!(!J.test(r)||Q.test(r)))return r}return null}function _(t){return t.message===""?t.name:`${t.name}: ${t.message}`}function x(t,e){if(t)return;let n;z()?n=Y:typeof e=="function"?n=e():n=e;let r=new T(n);throw $?.({name:r.name,frame:Z(r)}),r}var te=11,ne=26;function I(t){if(!(t instanceof Error))return!1;let e=t.errcode;if(typeof e=="number"){let r=e&255;if(r===te||r===ne)return!0}let n=t.message.toLowerCase();return n.includes("malformed")||n.includes("is not a database")||n.includes("database disk image")}var f=require("node:path"),F=require("node:sqlite");function s(t){let e=t.split(/[/\\]/),n=e[e.length-1]??"",r=n.lastIndexOf(".");return r<=0||r===n.length-1?null:n.slice(r+1).toLowerCase()}var re=new Set(["txt","text","log","md","markdown","mdx","rst","adoc","tex","json","jsonc","json5","ndjson","csv","tsv","xml","yaml","yml","toml","ini","cfg","conf","env","properties","plist","gradle","html","htm","css","scss","sass","less","svg","js","jsx","mjs","cjs","ts","tsx","mts","cts","py","pyi","rb","go","rs","java","kt","kts","c","h","cc","cpp","cxx","hpp","hh","cs","php","swift","scala","dart","lua","pl","pm","r","sql","graphql","gql","proto","vue","svelte","astro","sh","bash","zsh","fish","bat","ps1","tf","tfvars","dockerfile","diff","patch"]);function R(t){let e=s(t);return e!=null&&re.has(e)}var Ve=8*1024;function u(t){let e=t.slice(Math.max(t.lastIndexOf("/"),t.lastIndexOf("\\"))+1),n=e.lastIndexOf(".");return n<=0?"":e.slice(n).toLowerCase()}var m={".avif":"image/avif",".bmp":"image/bmp",".gif":"image/gif",".ico":"image/x-icon",".jpeg":"image/jpeg",".jpg":"image/jpeg",".png":"image/png",".svg":"image/svg+xml",".webp":"image/webp"};var p={".m4v":"video/mp4",".mov":"video/quicktime",".mp4":"video/mp4",".ogv":"video/ogg",".webm":"video/webm"},y={".aac":"audio/aac",".flac":"audio/flac",".m4a":"audio/mp4",".mp3":"audio/mpeg",".oga":"audio/ogg",".ogg":"audio/ogg",".opus":"audio/ogg",".wav":"audio/wav",".weba":"audio/webm"};var oe=new Set(Object.keys(m).map(t=>t.slice(1))),ie=new Set(Object.keys(p).map(t=>t.slice(1))),ae=new Set(Object.keys(y).map(t=>t.slice(1))),se=new Set(["md","markdown","mdx"]),de=new Set(["json"]),le=new Set(["csv","tsv","xlsx","xls"]);function M(t){let e=s(t);return e==null?"unknown":oe.has(e)?"image":ie.has(e)?"video":ae.has(e)?"audio":e==="pdf"?"pdf":le.has(e)?"table":de.has(e)?"json":se.has(e)?"markdown":e==="docx"?"docx":R(t)?"text":"unknown"}var ce=new Set(["json","jsonc","json5","ndjson"]),ue=new Set(["zip","tar","gz","tgz","bz2","tbz2","xz","txz","zst","7z","rar"]),me=new Set(["text/csv","text/tab-separated-values","application/vnd.ms-excel","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]),pe=new Set(["application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document"]),ye=new Set(["application/zip","application/x-zip-compressed","application/gzip","application/x-tar","application/x-bzip2","application/x-xz","application/zstd","application/x-7z-compressed","application/x-rar-compressed","application/vnd.rar"]);function ge(t){let e=(t.split(";")[0]??"").trim().toLowerCase();return e.startsWith("image/")?"image":e.startsWith("video/")?"video":e.startsWith("audio/")?"audio":e==="application/pdf"?"pdf":e==="text/markdown"?"markdown":me.has(e)?"table":e==="application/json"||e.endsWith("+json")?"json":pe.has(e)?"document":ye.has(e)?"archive":e.startsWith("text/")?"text":null}function fe(t){let e;try{e=new URL(t).pathname}catch{return t}try{return decodeURIComponent(e)}catch{return e}}function N(t){let e=fe(t),n=M(e);switch(n){case"image":case"video":case"audio":case"pdf":case"markdown":case"table":return n;case"docx":return"document";case"json":return"json";case"text":{let o=s(e);return o!=null&&ce.has(o)?"json":"text"}case"unknown":{let o=s(e);return o!=null&&ue.has(o)?"archive":null}}return n}function v(t){if(t.mimeType!=null&&t.mimeType.length>0){let e=ge(t.mimeType);if(e!=null)return e}if(t.fileName!=null&&t.fileName.length>0){let e=N(t.fileName);if(e!=null)return e}if(t.urlOrPath!=null&&t.urlOrPath.length>0){let e=N(t.urlOrPath);if(e!=null)return e}return"file"}var w=["image","video","audio","pdf","markdown","table","json","text","document","archive","file"];function O(t){return m[u(t)]}function P(t){return p[u(t)]}function k(t){return y[u(t)]}function Ee(t){return t!=null&&t.kind==="message"&&t.toAgent!=null}function b(t){return Ee(t)&&t.toAgent.kind!=="agent"}var Se=require("node:sqlite"),g=5e3;function D(t){switch(t.kind){case"message":return t.content;case"send-message":return t.message.type==="text"?t.message.content:"";case"notice":return t.text;default:return""}}var he=2e4;var Te="reconcile_done",ht=new Set(w);var xe=`
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
) STRICT;
CREATE TABLE IF NOT EXISTS agents (
  agent_id TEXT PRIMARY KEY,
  fingerprint TEXT NOT NULL
) STRICT;
CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY,
  agent_id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  timestamp_ms INTEGER NOT NULL,
  body TEXT NOT NULL,
  UNIQUE(agent_id, entry_id)
) STRICT;
CREATE INDEX IF NOT EXISTS messages_agent_recency
  ON messages(agent_id, timestamp_ms DESC);
CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
  body,
  content='messages',
  content_rowid='id',
  tokenize='unicode61 remove_diacritics 2',
  prefix='2 3'
);
CREATE TRIGGER IF NOT EXISTS messages_fts_insert AFTER INSERT ON messages BEGIN
  INSERT INTO messages_fts(rowid, body) VALUES (new.id, new.body);
END;
CREATE TRIGGER IF NOT EXISTS messages_fts_delete AFTER DELETE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, body)
    VALUES ('delete', old.id, old.body);
END;
CREATE TRIGGER IF NOT EXISTS messages_fts_update AFTER UPDATE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, body)
    VALUES ('delete', old.id, old.body);
  INSERT INTO messages_fts(rowid, body) VALUES (new.id, new.body);
END;
CREATE TABLE IF NOT EXISTS media (
  id INTEGER PRIMARY KEY,
  agent_id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  ext TEXT NOT NULL,
  mime TEXT,
  kind TEXT NOT NULL,
  timestamp_ms INTEGER NOT NULL,
  width INTEGER,
  height INTEGER,
  UNIQUE(agent_id, entry_id)
) STRICT;
CREATE INDEX IF NOT EXISTS media_recency ON media(timestamp_ms DESC);
CREATE VIRTUAL TABLE IF NOT EXISTS media_fts USING fts5(
  file_name,
  content='media',
  content_rowid='id',
  tokenize='unicode61 remove_diacritics 2',
  prefix='2 3'
);
CREATE TRIGGER IF NOT EXISTS media_fts_insert AFTER INSERT ON media BEGIN
  INSERT INTO media_fts(rowid, file_name) VALUES (new.id, new.file_name);
END;
CREATE TRIGGER IF NOT EXISTS media_fts_delete AFTER DELETE ON media BEGIN
  INSERT INTO media_fts(media_fts, rowid, file_name)
    VALUES ('delete', old.id, old.file_name);
END;
CREATE TRIGGER IF NOT EXISTS media_fts_update AFTER UPDATE ON media BEGIN
  INSERT INTO media_fts(media_fts, rowid, file_name)
    VALUES ('delete', old.id, old.file_name);
  INSERT INTO media_fts(rowid, file_name) VALUES (new.id, new.file_name);
END;
`;function U(t){let e=new F.DatabaseSync(t);try{return e.exec(`PRAGMA busy_timeout = ${g}`),e.exec("PRAGMA journal_mode = WAL"),e.exec("PRAGMA synchronous = NORMAL"),e.exec("PRAGMA auto_vacuum = INCREMENTAL"),e}catch(n){try{e.close()}catch{}throw n}}function B(t){t.exec(xe)}function W(t){t.prepare("INSERT INTO meta (key, value) VALUES (?, '1') ON CONFLICT(key) DO UPDATE SET value = '1'").run(Te)}function X(t){if(b(t))return null;let e=D(t).trim();return e.length===0?null:{entryId:t.id,role:t.kind==="message"?t.role:"assistant",timestampMs:G(t.timestampMs),body:e.slice(0,he)}}function G(t){return typeof t=="number"&&Number.isFinite(t)?Math.round(t):0}function C(t){return typeof t=="number"&&Number.isFinite(t)?Math.round(t):null}function L(t,e){let n=t?.trim();if(n!=null&&n.length>0)return n;let r=e;try{r=new URL(e).pathname}catch{}try{r=decodeURIComponent(r)}catch{}return(0,f.basename)(r)}function j(t){let e,n,r=null,o=null;if(t.kind==="user-attachment")n=t.file_path,e=L(t.file_name,n),r=C(t.width),o=C(t.height);else if(t.kind==="send-message"&&t.message.type==="attachment")n=t.message.url,e=L(t.message.file_name,n);else return null;if(e.length===0)return null;let i=(0,f.extname)(e).toLowerCase(),c=O(e)??P(e)??k(e)??null;return{entryId:t.id,fileName:e,ext:i,mime:c,kind:v({fileName:e,urlOrPath:n}),timestampMs:G(t.timestampMs),width:r,height:o}}var d=require("node:fs"),H=require("node:path"),q=require("node:sqlite");var be="store.db",K=512;function Ae(t){return{upsertMessage:t.prepare(`INSERT INTO messages (agent_id, entry_id, role, timestamp_ms, body)
			 VALUES (?, ?, ?, ?, ?)
			 ON CONFLICT(agent_id, entry_id) DO UPDATE SET
				role = excluded.role,
				timestamp_ms = excluded.timestamp_ms,
				body = excluded.body`),deleteMessage:t.prepare("DELETE FROM messages WHERE agent_id = ? AND entry_id = ?"),deleteAgentMessages:t.prepare("DELETE FROM messages WHERE agent_id = ?"),upsertMedia:t.prepare(`INSERT INTO media (
				agent_id, entry_id, file_name, ext, mime, kind,
				timestamp_ms, width, height
			 )
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
			 ON CONFLICT(agent_id, entry_id) DO UPDATE SET
				file_name = excluded.file_name,
				ext = excluded.ext,
				mime = excluded.mime,
				kind = excluded.kind,
				timestamp_ms = excluded.timestamp_ms,
				width = excluded.width,
				height = excluded.height`),deleteMedia:t.prepare("DELETE FROM media WHERE agent_id = ? AND entry_id = ?"),deleteAgentMedia:t.prepare("DELETE FROM media WHERE agent_id = ?"),upsertFingerprint:t.prepare(`INSERT INTO agents (agent_id, fingerprint) VALUES (?, ?)
			 ON CONFLICT(agent_id) DO UPDATE SET fingerprint = excluded.fingerprint`),deleteFingerprint:t.prepare("DELETE FROM agents WHERE agent_id = ?"),readFingerprint:t.prepare("SELECT fingerprint FROM agents WHERE agent_id = ?"),listIndexedAgentIds:t.prepare(`SELECT agent_id AS agentId FROM agents
			 UNION SELECT DISTINCT agent_id FROM messages
			 UNION SELECT DISTINCT agent_id FROM media`)}}var E=class{constructor(e,n){this.db=e;this.agentsRootDir=n;this.statements=Ae(e)}db;agentsRootDir;statements;storeConnections=new Map;close(){for(let e of this.storeConnections.values())try{e.db.close()}catch{}this.storeConnections.clear()}runJob(e){switch(e.kind){case"upsert-entries":this.upsertEntries(e.agentId,e.entries);return;case"delete-entry":this.deleteEntry(e.agentId,e.entryId);return;case"clear-agent":this.clearAgent(e.agentId);return;case"reindex-agents":for(let n of e.agentIds)this.reindexAgent(n);return;case"reconcile":this.reconcile();return}}storeDbPath(e){return(0,H.join)(this.agentsRootDir,e,be)}evictStoreConnection(e){let n=this.storeConnections.get(e);if(n!=null){this.storeConnections.delete(e);try{n.db.close()}catch{}}}storeConnection(e){let n=this.storeConnections.get(e);if(n!=null)return n;let r=this.storeDbPath(e);if(!(0,d.existsSync)(r))return null;try{let o=new q.DatabaseSync(r,{readOnly:!0});o.exec(`PRAGMA busy_timeout = ${g}`);let i={db:o};return this.storeConnections.set(e,i),i}catch{return null}}readStoreFingerprint(e){let n=this.storeConnection(e);if(n==null)return null;try{let r=n.db.prepare("SELECT COUNT(*) AS count, COALESCE(MAX(seq), 0) AS maxSeq FROM transcript_entries").get();return r==null||typeof r.count!="number"||typeof r.maxSeq!="number"?null:`${r.count}:${r.maxSeq}`}catch{return this.evictStoreConnection(e),null}}inTransaction(e){this.db.exec("BEGIN IMMEDIATE");try{e(),this.db.exec("COMMIT")}catch(n){try{this.db.exec("ROLLBACK")}catch{}throw n}}applyEntry(e,n){let r=null,o=null;try{r=X(n),o=j(n)}catch{}r!=null?this.statements.upsertMessage.run(e,r.entryId,r.role,r.timestampMs,r.body):this.statements.deleteMessage.run(e,n.id),o!=null?this.statements.upsertMedia.run(e,o.entryId,o.fileName,o.ext,o.mime,o.kind,o.timestampMs,o.width,o.height):this.statements.deleteMedia.run(e,n.id)}refreshFingerprint(e){let n=this.readStoreFingerprint(e);n==null?this.statements.deleteFingerprint.run(e):this.statements.upsertFingerprint.run(e,n)}upsertEntries(e,n){n.length!==0&&this.inTransaction(()=>{for(let r of n)this.applyEntry(e,r);this.refreshFingerprint(e)})}deleteEntry(e,n){this.inTransaction(()=>{this.statements.deleteMessage.run(e,n),this.statements.deleteMedia.run(e,n),this.refreshFingerprint(e)})}clearAgent(e){this.evictStoreConnection(e),this.inTransaction(()=>{this.statements.deleteAgentMessages.run(e),this.statements.deleteAgentMedia.run(e),this.statements.deleteFingerprint.run(e)}),this.db.exec(`PRAGMA incremental_vacuum(${K})`)}reindexAgent(e){if(this.evictStoreConnection(e),!(0,d.existsSync)(this.storeDbPath(e))){this.clearAgent(e);return}let n=this.storeConnection(e);if(n==null)return;let r;try{r=n.db.prepare("SELECT seq, entry FROM transcript_entries ORDER BY seq").all()}catch{this.evictStoreConnection(e);return}let o=0,i=[];for(let a of r)if(typeof a.seq=="number"&&a.seq>o&&(o=a.seq),typeof a.entry=="string")try{let l=JSON.parse(a.entry);l!=null&&typeof l=="object"&&typeof l.id=="string"&&typeof l.kind=="string"&&i.push(l)}catch{}let c=`${r.length}:${o}`;this.inTransaction(()=>{this.statements.deleteAgentMessages.run(e),this.statements.deleteAgentMedia.run(e);for(let a of i)this.applyEntry(e,a);this.statements.upsertFingerprint.run(e,c)}),this.db.exec(`PRAGMA incremental_vacuum(${K})`)}reconcile(){let e;try{e=(0,d.readdirSync)(this.agentsRootDir,{withFileTypes:!0}).filter(o=>o.isDirectory()).map(o=>o.name)}catch{e=[]}let n=new Set(e),r=this.statements.listIndexedAgentIds.all();for(let o of r)typeof o.agentId=="string"&&(n.has(o.agentId)||this.clearAgent(o.agentId));for(let o of e){if(!(0,d.existsSync)(this.storeDbPath(o)))continue;let i=this.readStoreFingerprint(o);if(i==null)continue;this.statements.readFingerprint.get(o)?.fingerprint!==i&&this.reindexAgent(o)}W(this.db)}};var A=h.parentPort;x(A!=null,"search-index-worker must run as a worker_thread");var S=h.workerData;x(typeof S?.indexDbPath=="string"&&typeof S?.agentsRootDir=="string","search-index-worker needs indexDbPath + agentsRootDir");var V=U(S.indexDbPath);B(V);var _e=new E(V,S.agentsRootDir);A.on("message",t=>{let e;try{_e.runJob(t.job),e={requestId:t.requestId,ok:!0}}catch(n){e={requestId:t.requestId,ok:!1,message:n instanceof Error?n.message:String(n),isIndexCorrupt:I(n)}}A.postMessage(e)});
