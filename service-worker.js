const CACHE = "bull-v29";
const SHELL = [
  "./",
  "./index.html",
  "./app.js",
  "./manifest.json",
  "./preview-b-bull.png",
  "./art/devil-1.png",
  "./art/devil-2.png",
  "./art/devil-3.png",
  "./art/devil-4.png",
  "./art/devil-5.png",
  "./art/physique-1.png",
  "./art/physique-2.png",
  "./art/physique-3.png",
  "./art/physique-4.png",
  "./art/physique-5.png",
];

/* Each shell file is cached individually — physique-1.png doesn't exist on the repo
   yet (held back pending a redo), and one missing file must not fail the whole
   precache the way a single addAll() would. */
self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => Promise.all(SHELL.map((u) => c.add(u).catch(() => {}))))
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
