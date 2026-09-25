// GOLDING'S PREDICTION service worker.
// Network first, so the installed app always shows the latest predictions;
// the last copy is kept so the app still opens when you are offline.
// Changing this file (e.g. the cache name) makes installed apps pick up the new version.
const CACHE = "goldings-prediction-v2";
const SHELL = ["./", "manifest.webmanifest", "icon-192.png", "icon-512.png"];

// Save the dashboard straight away, so the app opens offline even right after installing.
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(SHELL.map((url) => new Request(url, { cache: "reload" }))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) return;
  // Ask the server every time ("no-cache" revalidates any copy the browser kept),
  // so a new edition is on screen the moment it is published.
  const fresh = request.mode === "navigate"
    ? new Request(request.url, { cache: "no-cache", credentials: "same-origin", redirect: "manual" })
    : new Request(request, { cache: "no-cache" });
  event.respondWith(
    fetch(fresh)
      .then((response) => {
        if (response.ok) {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(request, copy));
        }
        return response;
      })
      .catch(() => caches.match(request).then((cached) => cached || caches.match("./")))
  );
});
