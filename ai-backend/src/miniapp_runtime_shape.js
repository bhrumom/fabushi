export const CHROME_EXTENSION_PLATFORM = 'chrome-extension';
export const MINIAPP_RUNTIME_FORM = 'miniapp';
export const USERSCRIPT_RUNTIME_FORM = 'userscript';

function normalized(values) {
  return [...new Set((values ?? []).map((value) => String(value ?? '').trim().toLocaleLowerCase()).filter(Boolean))];
}

export function runtimeFormForManifest(manifest) {
  const tags = normalized(manifest?.tags);
  const categories = normalized(manifest?.categories);
  return tags.includes(USERSCRIPT_RUNTIME_FORM) || categories.includes(USERSCRIPT_RUNTIME_FORM)
    ? USERSCRIPT_RUNTIME_FORM
    : MINIAPP_RUNTIME_FORM;
}

export function compatiblePlatformsForManifest(manifest) {
  return normalized((manifest?.surfaces ?? []).flatMap((surface) => surface?.platforms ?? []));
}

export function marketplaceRuntimeShape(manifest) {
  return {
    form: runtimeFormForManifest(manifest),
    platforms: compatiblePlatformsForManifest(manifest),
  };
}

export function manifestVisibleOnPlatform(manifest, platform) {
  const runtimeForm = runtimeFormForManifest(manifest);
  const requestedPlatform = String(platform ?? '').trim().toLocaleLowerCase();
  if (runtimeForm === USERSCRIPT_RUNTIME_FORM) {
    return requestedPlatform === CHROME_EXTENSION_PLATFORM;
  }
  if (!requestedPlatform) return true;
  const platforms = compatiblePlatformsForManifest(manifest);
  return platforms.includes('all') || platforms.includes(requestedPlatform);
}
