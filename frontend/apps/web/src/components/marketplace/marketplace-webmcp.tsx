"use client";

import { useEffect } from "react";
import { registerWebMcpTool } from "@fabushi/mcp-app-sdk";
import {
  MARKETPLACE_CATEGORY_LABELS,
  getMarketplaceApp,
  getMarketplaceContent,
  marketplaceApps,
  searchMarketplace,
} from "../../lib/marketplace";
import { siteUrl } from "../../lib/site-url";

const INSTALLED_KEY = "fabushi.installed-miniapps";

function asPositiveLimit(value: unknown, fallback = 10) {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(30, Math.floor(parsed)));
}

function readInstalledApps() {
  try {
    const parsed = JSON.parse(window.localStorage.getItem(INSTALLED_KEY) ?? "[]");
    return Array.isArray(parsed)
      ? parsed.filter((item): item is string => typeof item === "string")
      : [];
  } catch {
    return [];
  }
}

export function MarketplaceWebMcp() {
  useEffect(() => {
    const disposers = [
      registerWebMcpTool({
        name: "search_fabushi_marketplace",
        title: "Search Fabushi apps and content",
        description:
          "Search the Fabushi Mini App marketplace across app names, capabilities, tags, guides, templates and workflows. Returns stable deep links for every result.",
        annotations: { readOnlyHint: true },
        inputSchema: {
          type: "object",
          properties: {
            query: { type: "string", description: "Search terms in Chinese or English." },
            kind: {
              type: "string",
              enum: ["all", "apps", "content"],
              description: "Optional result kind. Defaults to all.",
            },
            limit: { type: "number", minimum: 1, maximum: 30, description: "Maximum results per kind." },
          },
          required: ["query"],
        },
        execute: (input) => {
          const query = typeof input.query === "string" ? input.query : "";
          const kind = input.kind === "apps" || input.kind === "content" ? input.kind : "all";
          const limit = asPositiveLimit(input.limit);
          const results = searchMarketplace(query);
          return {
            query,
            apps:
              kind === "content"
                ? []
                : results.apps.slice(0, limit).map((app) => ({
                    id: app.id,
                    slug: app.slug,
                    name: app.name,
                    subtitle: app.subtitle,
                    category: MARKETPLACE_CATEGORY_LABELS[app.category],
                    tags: app.tags,
                    detailsUrl: siteUrl(`/apps/${app.slug}`),
                    launchUrl: siteUrl(`/miniapps/${app.id}`),
                  })),
            content:
              kind === "apps"
                ? []
                : results.content.slice(0, limit).map(({ app, item }) => ({
                    id: item.id,
                    app: app.name,
                    appSlug: app.slug,
                    type: item.type,
                    title: item.title,
                    summary: item.summary,
                    keywords: item.keywords,
                    url: siteUrl(`/apps/${app.slug}/content/${item.id}`),
                  })),
          };
        },
      }),
      registerWebMcpTool({
        name: "get_fabushi_app",
        title: "Get a Fabushi app listing",
        description:
          "Get the complete public listing for a Fabushi Mini App, including capabilities, permissions, pricing, version, content entries and launch URL.",
        annotations: { readOnlyHint: true },
        inputSchema: {
          type: "object",
          properties: {
            slug: { type: "string", description: "The app slug or Mini App ID." },
          },
          required: ["slug"],
        },
        execute: (input) => {
          const slug = typeof input.slug === "string" ? input.slug : "";
          const app = getMarketplaceApp(slug);
          if (!app) return { found: false, slug };
          return {
            found: true,
            app: {
              ...app,
              categoryLabel: MARKETPLACE_CATEGORY_LABELS[app.category],
              detailsUrl: siteUrl(`/apps/${app.slug}`),
              launchUrl: siteUrl(`/miniapps/${app.id}`),
              content: app.content.map((item) => ({
                ...item,
                url: siteUrl(`/apps/${app.slug}/content/${item.id}`),
              })),
            },
          };
        },
      }),
      registerWebMcpTool({
        name: "get_fabushi_content",
        title: "Get Fabushi content by deep link ID",
        description:
          "Retrieve one public guide, template, collection, workflow or release entry from a Fabushi app using its stable app slug and content ID.",
        annotations: { readOnlyHint: true },
        inputSchema: {
          type: "object",
          properties: {
            appSlug: { type: "string", description: "The parent app slug." },
            contentId: { type: "string", description: "The stable content ID." },
          },
          required: ["appSlug", "contentId"],
        },
        execute: (input) => {
          const appSlug = typeof input.appSlug === "string" ? input.appSlug : "";
          const contentId = typeof input.contentId === "string" ? input.contentId : "";
          const result = getMarketplaceContent(appSlug, contentId);
          if (!result) return { found: false, appSlug, contentId };
          return {
            found: true,
            app: {
              id: result.app.id,
              slug: result.app.slug,
              name: result.app.name,
              detailsUrl: siteUrl(`/apps/${result.app.slug}`),
              launchUrl: siteUrl(`/miniapps/${result.app.id}`),
            },
            content: {
              ...result.item,
              url: siteUrl(`/apps/${result.app.slug}/content/${result.item.id}`),
            },
          };
        },
      }),
      registerWebMcpTool({
        name: "install_fabushi_app",
        title: "Install a Fabushi app",
        description:
          "Add a Fabushi Mini App to the current user's installed workspace. This changes local marketplace state and always asks the user for confirmation before writing.",
        annotations: { readOnlyHint: false },
        inputSchema: {
          type: "object",
          properties: {
            slug: { type: "string", description: "The app slug or Mini App ID to install." },
          },
          required: ["slug"],
        },
        execute: (input) => {
          const slug = typeof input.slug === "string" ? input.slug : "";
          const app = getMarketplaceApp(slug);
          if (!app) return { installed: false, error: "app_not_found", slug };

          const installed = readInstalledApps();
          if (installed.includes(app.id)) {
            return {
              installed: true,
              alreadyInstalled: true,
              appId: app.id,
              launchUrl: siteUrl(`/miniapps/${app.id}`),
            };
          }

          if (!window.confirm(`将 ${app.name} 安装到“我的应用”？`)) {
            return { installed: false, cancelled: true, appId: app.id };
          }

          const next = [...new Set([...installed, app.id])];
          window.localStorage.setItem(INSTALLED_KEY, JSON.stringify(next));
          window.dispatchEvent(
            new CustomEvent("fabushi:marketplace-installed", { detail: { ids: next } }),
          );
          return {
            installed: true,
            appId: app.id,
            detailsUrl: siteUrl(`/apps/${app.slug}`),
            launchUrl: siteUrl(`/miniapps/${app.id}`),
          };
        },
      }),
      registerWebMcpTool({
        name: "list_fabushi_marketplace_categories",
        title: "List Fabushi marketplace categories",
        description: "List public Fabushi app categories and the apps currently available in each category.",
        annotations: { readOnlyHint: true },
        inputSchema: { type: "object", properties: {} },
        execute: () => ({
          categories: Object.entries(MARKETPLACE_CATEGORY_LABELS).map(([id, label]) => ({
            id,
            label,
            apps:
              id === "featured"
                ? marketplaceApps.filter((app) => app.featured).map((app) => app.slug)
                : marketplaceApps.filter((app) => app.category === id).map((app) => app.slug),
          })),
        }),
      }),
    ];

    window.dispatchEvent(
      new CustomEvent("fabushi:marketplace-webmcp-ready", {
        detail: {
          tools: [
            "search_fabushi_marketplace",
            "get_fabushi_app",
            "get_fabushi_content",
            "install_fabushi_app",
            "list_fabushi_marketplace_categories",
          ],
        },
      }),
    );

    return () => {
      for (const dispose of disposers.reverse()) dispose();
    };
  }, []);

  return null;
}
