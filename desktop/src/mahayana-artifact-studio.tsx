import { ExternalLink, FileOutput, LayoutTemplate, PackageOpen, X } from 'lucide-react';
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { invokeNativeDesktop } from '../../frontend/apps/web/src/lib/fabushi-runtime/native-desktop';
import { MAHAYANA_RUNTIME_EVENT_NAME } from '../../frontend/apps/web/src/lib/mahayana-host/electron-transport';
import styles from './mahayana-artifact-studio.module.css';

type ArtifactManifest = {
  schemaVersion: 'mahayana-artifact/v1';
  id: string;
  name: string;
  kind: 'miniapp' | 'web' | 'dashboard' | 'document' | 'deck' | 'image' | 'video' | 'audio' | 'data';
  entrypoint: string;
  workspaceId?: string;
  designSystemId?: string;
  preview?: { renderer?: string; sandboxed?: boolean };
  exports?: string[];
  miniApp?: { publishable?: boolean; runtime?: string; marketplaceHandoff?: boolean };
};

type ArtifactRecord = {
  manifest: ArtifactManifest;
  operationId?: string;
  discoveredAtMs: number;
};

type PreviewDocument = {
  renderer: string;
  sandboxed: boolean;
  allowNetwork: string;
  entrypoint: string;
  available: boolean;
  html?: string;
  bytes?: number;
  reason?: string;
};

type ExporterList = { kind: string; formats: string[]; executionOwner: string; failClosed: boolean };

type MiniAppHandoff = {
  type: 'fabushi-miniapp-publish-handoff/v1';
  artifactId: string;
  entrypoint: string;
  workspaceId: string | null;
  designSystemId: string;
  requestedVisibility: string;
  requiresExistingMarketplacePipeline: boolean;
  requiresCapabilityReview: boolean;
};

const MAX_ARTIFACTS = 12;

function isArtifactManifest(value: unknown): value is ArtifactManifest {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const candidate = value as Partial<ArtifactManifest>;
  return candidate.schemaVersion === 'mahayana-artifact/v1' &&
    typeof candidate.id === 'string' &&
    typeof candidate.name === 'string' &&
    typeof candidate.kind === 'string' &&
    typeof candidate.entrypoint === 'string';
}

export function extractArtifactManifests(value: unknown, depth = 0, seen = new Set<unknown>()): ArtifactManifest[] {
  if (depth > 6 || value == null) return [];
  if (isArtifactManifest(value)) return [value];
  if (typeof value !== 'object' || seen.has(value)) return [];
  seen.add(value);
  const children = Array.isArray(value) ? value.slice(0, 80) : Object.values(value as Record<string, unknown>).slice(0, 80);
  const out: ArtifactManifest[] = [];
  for (const child of children) {
    for (const manifest of extractArtifactManifests(child, depth + 1, seen)) {
      if (!out.some((existing) => existing.id === manifest.id)) out.push(manifest);
    }
  }
  return out;
}

function ensurePortalRoot(): HTMLElement | null {
  const messageArea = document.querySelector<HTMLElement>('[data-testid="messenger-workspace"] [class*="messageArea"]');
  const existing = document.getElementById('mahayana-artifact-studio-portal');
  if (!messageArea) {
    existing?.remove();
    return null;
  }
  const root = existing || document.createElement('div');
  root.id = 'mahayana-artifact-studio-portal';
  if (root.parentElement !== messageArea) messageArea.appendChild(root);
  return root;
}

function kindLabel(kind: ArtifactManifest['kind']): string {
  const labels: Record<ArtifactManifest['kind'], string> = {
    miniapp: 'MiniApp', web: '网页', dashboard: 'Dashboard', document: '文档', deck: '演示文稿',
    image: '图片', video: '视频', audio: '音频', data: '数据',
  };
  return labels[kind];
}

export default function MahayanaArtifactStudio() {
  const [artifacts, setArtifacts] = useState<ArtifactRecord[]>([]);
  const [portal, setPortal] = useState<HTMLElement | null>(null);
  const [preview, setPreview] = useState<{ artifact: ArtifactManifest; document: PreviewDocument } | null>(null);
  const [exporters, setExporters] = useState<Record<string, ExporterList>>({});
  const [handoff, setHandoff] = useState<MiniAppHandoff | null>(null);
  const [error, setError] = useState<string | null>(null);
  const recordsRef = useRef(artifacts);
  recordsRef.current = artifacts;

  useEffect(() => {
    const onRuntime = (event: Event) => {
      const detail = (event as CustomEvent<unknown>).detail;
      const manifests = extractArtifactManifests(detail);
      if (!manifests.length) return;
      const operationId = detail && typeof detail === 'object' && !Array.isArray(detail)
        ? String((detail as Record<string, unknown>).operationId || '') || undefined
        : undefined;
      setArtifacts((current) => {
        const next = [...current];
        for (const manifest of manifests) {
          const index = next.findIndex((item) => item.manifest.id === manifest.id);
          const record = { manifest, operationId, discoveredAtMs: Date.now() };
          if (index >= 0) next[index] = record;
          else next.push(record);
        }
        return next.slice(-MAX_ARTIFACTS);
      });
    };
    window.addEventListener(MAHAYANA_RUNTIME_EVENT_NAME, onRuntime);
    return () => window.removeEventListener(MAHAYANA_RUNTIME_EVENT_NAME, onRuntime);
  }, []);

  useEffect(() => {
    const refresh = () => setPortal((current) => {
      const next = ensurePortalRoot();
      return next === current ? current : next;
    });
    const observer = new MutationObserver(refresh);
    observer.observe(document.body, { childList: true, subtree: true });
    refresh();
    return () => {
      observer.disconnect();
      document.getElementById('mahayana-artifact-studio-portal')?.remove();
    };
  }, []);

  const visible = useMemo(() => artifacts.slice(-4), [artifacts]);

  const openPreview = async (artifact: ArtifactManifest) => {
    setError(null);
    setHandoff(null);
    try {
      const document = await invokeNativeDesktop<PreviewDocument>('getArtifactPreviewDocument', { manifest: artifact });
      if (!document.available) throw new Error(document.reason || '该 Artifact 需要专用预览器。');
      setPreview({ artifact, document });
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const inspectExports = async (artifact: ArtifactManifest) => {
    setError(null);
    try {
      const result = await invokeNativeDesktop<ExporterList>('listArtifactExporters', { kind: artifact.kind });
      setExporters((current) => ({ ...current, [artifact.id]: result }));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const prepareMiniApp = async (artifact: ArtifactManifest) => {
    setError(null);
    setPreview(null);
    try {
      const result = await invokeNativeDesktop<MiniAppHandoff>('createMiniAppPublishHandoff', { manifest: artifact, visibility: 'private' });
      setHandoff(result);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  if (!portal || !visible.length) return preview ? (
    <PreviewModal preview={preview} onClose={() => setPreview(null)} />
  ) : null;

  const panel = (
    <section className={styles.studio} data-testid="mahayana-artifact-studio">
      <header><LayoutTemplate size={16} /><strong>Artifact Studio</strong><span>真实文件 · Fabushi Design</span></header>
      {visible.map(({ manifest }) => {
        const available = exporters[manifest.id];
        return (
          <article className={styles.card} data-testid="mahayana-artifact-card" data-kind={manifest.kind} key={manifest.id}>
            <div className={styles.identity}>
              <PackageOpen size={18} />
              <span><strong>{manifest.name}</strong><small>{kindLabel(manifest.kind)} · {manifest.entrypoint}</small></span>
            </div>
            <div className={styles.actions}>
              {manifest.kind === 'web' || manifest.kind === 'dashboard' ? (
                <button type="button" disabled={!manifest.workspaceId} onClick={() => void openPreview(manifest)}><ExternalLink size={13} />实时预览</button>
              ) : null}
              {manifest.kind === 'miniapp' ? (
                <button type="button" onClick={() => void prepareMiniApp(manifest)}><PackageOpen size={13} />进入 MiniApp 管线</button>
              ) : null}
              <button type="button" onClick={() => void inspectExports(manifest)}><FileOutput size={13} />导出</button>
            </div>
            {available ? <small className={styles.formats}>可用格式：{available.formats.join(' · ')}</small> : null}
          </article>
        );
      })}
      {handoff ? <div className={styles.notice} data-testid="miniapp-publish-handoff">MiniApp 已准备交给现有市场/能力审查管线：{handoff.artifactId}</div> : null}
      {error ? <div className={styles.error}>{error}</div> : null}
    </section>
  );

  return (
    <>
      {createPortal(panel, portal)}
      {preview ? <PreviewModal preview={preview} onClose={() => setPreview(null)} /> : null}
    </>
  );
}

function PreviewModal({ preview, onClose }: { preview: { artifact: ArtifactManifest; document: PreviewDocument }; onClose: () => void }) {
  return createPortal(
    <div className={styles.backdrop} role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section className={styles.modal} role="dialog" aria-modal="true" aria-label={`${preview.artifact.name} Artifact 预览`}>
        <header><div><strong>{preview.artifact.name}</strong><small>Sandboxed · network disabled · {preview.document.bytes ?? 0} bytes</small></div><button type="button" aria-label="关闭 Artifact 预览" onClick={onClose}><X size={18} /></button></header>
        <iframe title={`${preview.artifact.name} preview`} sandbox="allow-scripts" srcDoc={preview.document.html || ''} />
      </section>
    </div>,
    document.body,
  );
}
