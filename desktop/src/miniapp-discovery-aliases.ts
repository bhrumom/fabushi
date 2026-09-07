import {
  ElectronMahayanaHostTransport,
} from '../../frontend/apps/web/src/lib/mahayana-host/electron-transport';
import type { MarketplaceBrowseResult } from '../../frontend/apps/web/src/lib/mahayana-host/transport';

const INSTALL_MARKER = Symbol.for('fabushi.desktop.miniapp-discovery-aliases.v1');
const MINI_APP_DISCOVERY_ALIASES = new Set([
  '小程序',
  'mini app',
  'mini apps',
  'miniapp',
  'miniapps',
]);

type MarketplaceBrowse = (query?: string) => Promise<MarketplaceBrowseResult>;
type PatchableTransportPrototype = {
  marketplaceBrowse: MarketplaceBrowse;
  [INSTALL_MARKER]?: boolean;
};

export function normalizeMiniAppDiscoveryQuery(query?: string): string | undefined {
  const trimmed = query?.normalize('NFKC').trim();
  if (!trimmed) return undefined;
  const normalized = trimmed.toLocaleLowerCase().replace(/\s+/g, ' ');
  return MINI_APP_DISCOVERY_ALIASES.has(normalized) ? undefined : trimmed;
}

/**
 * The Marketplace endpoint performs content search. Generic category phrases
 * such as "小程序" / "Mini App" instead mean "show Mini Apps" in the desktop
 * Apps search tab. Normalize only those category aliases at the existing
 * Mahayana transport boundary; title/id/description searches remain untouched
 * and the Host remains authoritative for which apps are discoverable.
 */
export function installDesktopMiniAppDiscoveryAliases(): void {
  const prototype = ElectronMahayanaHostTransport.prototype as PatchableTransportPrototype;
  if (prototype[INSTALL_MARKER]) return;
  const browse = prototype.marketplaceBrowse;
  Object.defineProperty(prototype, INSTALL_MARKER, {
    configurable: false,
    enumerable: false,
    value: true,
    writable: false,
  });
  prototype.marketplaceBrowse = function marketplaceBrowseWithDiscoveryAliases(query?: string) {
    return browse.call(this, normalizeMiniAppDiscoveryQuery(query));
  };
}
