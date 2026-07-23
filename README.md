# Bull

Relapse prevention and sexual vigour tracker. Installs as a home screen app on iPhone. No build step — plain files, loaded via CDN.

Everything is stored in your phone's browser storage (`localStorage`), on-device only. Nothing is sent anywhere.

## Publish to GitHub Pages

**1. Create the repo**

On [github.com](https://github.com), click **New repository**. Name it `bull` (or anything you like). Keep it **Private** if you don't want the code public — Pages still works on private repos with a free GitHub account, though the *published site URL* is technically reachable by anyone who has the link, so don't put anything sensitive in the code itself (this app doesn't — all your data stays local to your phone).

**2. Push this folder**

Open Terminal (or your phone's a Shortcut/Working Copy app if pushing from iOS) and run, from inside this `bull-pwa` folder:

```bash
git init
git add .
git commit -m "Bull v1"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/bull.git
git push -u origin main
```

Replace `YOUR-USERNAME` with your GitHub username. It'll prompt for login — use a [personal access token](https://github.com/settings/tokens) as the password if asked (GitHub retired plain password pushes).

**3. Turn on Pages**

In the repo on GitHub: **Settings → Pages**. Under "Build and deployment", set **Source** to `Deploy from a branch`, branch `main`, folder `/ (root)`. Save.

Wait a minute or two, then your app is live at:

```
https://YOUR-USERNAME.github.io/bull/
```

**4. Install it on your phone**

Open that URL in Safari on iPhone. Tap the **Share** button → **Add to Home Screen**. It'll show the bull icon and open full-screen like a native app, no browser chrome.

## Updating later

Whenever you want to change something:

```bash
git add .
git commit -m "describe the change"
git push
```

GitHub Pages redeploys automatically within a minute or two. Refresh the app on your phone (or close and reopen it) to get the update — the service worker caches aggressively, so a hard refresh (or force-quitting the app) may be needed to see changes immediately.

## Alternative: Vercel or Netlify

If you'd rather not use GitHub Pages, both [vercel.com](https://vercel.com) and [netlify.com](https://netlify.com) let you drag-and-drop this whole folder in their dashboard for an instant live URL, no git required. Netlify's "Deploy manually" and Vercel's dashboard both support this directly.

## Files

- `index.html` — app shell, loads React from CDN via import map, no bundler
- `app.js` — the whole app
- `manifest.json` — PWA metadata, icon, name
- `service-worker.js` — offline caching
- `icons/` — the Bull icon at required sizes
