const CACHE = "bull-v41";
const SHELL = [
  "./",
  "./index.html",
  "./app.js",
  "./manifest.json",
  "./preview-b-bull.png",
  "./devil-1.png",
  "./devil-2.png",
  "./devil-3.png",
  "./devil-4.png",
  "./devil-5.png",
  "./physique-1.png",
  "./physique-2.png",
  "./physique-3.png",
  "./physique-4.png",
  "./physique-5.png",
];

/* cache.add() does a normal fetch, which can be satisfied by the browser's own HTTP
   cache — meaning a precache can silently capture stale content even on a brand new
   service worker version. { cache: "reload" } forces a real network round-trip for
   every shell file, bypassing HTTP cache entirely, not just this cache's own. Each
   file is still handled individually so one missing asset can't fail the whole
   install the way a single addAll() would. */
self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) =>
      Promise.all(SHELL.map((u) =>
        fetch(u, { cache: "reload" }).then((res) => c.put(u, res)).catch(() => {})
      ))
    )
  );
  self.skipWaiting();
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    caches.match(e.request).then((cached) => {
      const fetchPromise = fetch(e.request)
        .then((res) => {
          if (res && res.status === 200 && e.request.url.startsWith(self.location.origin)) {
            const copy = res.clone();
            caches.open(CACHE).then((c) => c.put(e.request, copy));
          }
          return res;
        })
        .catch(() => cached);
      return cached || fetchPromise;
    })
  );
});
