"use client";

import { useEffect } from "react";
import { installFabushiDomAppSurface } from "../lib/app-agent-surface/dom-agent-surface";

/**
 * Registers the Fabushi main Web application as a structured WebMCP/App MCP
 * surface. The installer feature-detects the browser WebMCP draft and always
 * keeps the same contract available through window.__fabushiAppMcp for trusted
 * Fabushi hosts and deterministic tests.
 */
export function FabushiAppAgentSurface() {
  useEffect(() => {
    const installed = installFabushiDomAppSurface({ appId: "fabushi.web", platform: "web" });
    return () => installed.dispose();
  }, []);
  return null;
}
