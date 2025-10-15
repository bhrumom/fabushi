#!/bin/bash
# This script is for building the Flutter web app and preparing it for Cloudflare Worker deployment.
set -e

# Change to the project root directory, which is the directory of this script.
cd "$(dirname "$0")"

echo "===== Building Flutter Web App for Cloudflare Worker ====="

# Build Flutter Web app
echo "Building Flutter Web app..."
flutter build web --release --base-href /

# Replace flutter_service_worker.js with a self-unregistering SW to bust old caches
echo "Injecting self-unregistering service worker to clear old caches..."
cat > build/web/flutter_service_worker.js <<'EOF'
self.addEventListener('install', (event) => {
  self.skipWaiting();
});
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    } catch (e) {
      // ignore
    }
    try {
      await self.registration.unregister();
    } catch (e) {
      // ignore
    }
    try {
      const allClients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of allClients) {
        client.navigate(client.url);
      }
    } catch (e) {
      // ignore
    }
  })());
});
self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
EOF

# Copy static assets to the build directory, skipping existing files
echo "Copying static assets (skipping existing files)..."
if [ -d "web/assets" ]; then
    # Use rsync with --ignore-existing to copy only new files.
    rsync -a --ignore-existing web/assets/ build/web/assets/
fi

# Generate the manifest for static assets
echo "Generating static asset manifest..."
if [ -f "generate-asset-manifest.js" ]; then
    node generate-asset-manifest.js
else
    echo "Warning: generate-asset-manifest.js not found. Skipping manifest generation."
fi

# Copy other necessary web files
echo "Copying other necessary web files..."
if [ -d "web/wasm-proxy/pkg" ]; then
    cp -r web/wasm-proxy/pkg build/web/wasm-proxy/
fi

if [ -f "web/service-worker.js" ]; then
    cp web/service-worker.js build/web/
fi

echo "===== Build complete ====="
echo "Build output is in: build/web"
echo "Ready for 'wrangler deploy'."