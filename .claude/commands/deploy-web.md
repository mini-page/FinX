# deploy-web — Build & Deploy the Expensioa Web SPA

## Purpose
Build and publish the static website (`website/` + `public_assets/`) for the Expensioa landing page / web presence.

> **Scope:** This command is for the **static HTML/CSS/JS website** located in `website/` and `public_assets/`, **not** for a Flutter Web build. The Expensioa landing page is a standard web SPA, not a Flutter app.

## Project Structure
```
website/         # HTML, CSS, JS source files
public_assets/   # Images, fonts, and other static assets served publicly
```

## Build Steps

1. **Validate HTML/CSS**
   ```bash
   # If a build tool (e.g. Vite, Parcel, or plain HTML) is used:
   # Run the project's build command, e.g.:
   npm run build     # if Node-based
   # or simply validate HTML files with a linter
   ```

2. **Check assets**
   - Ensure all images in `public_assets/` are optimized (WebP preferred).
   - Verify no broken links in HTML files.
   - Confirm `meta` tags (OG, description, viewport) are present in `index.html`.

3. **Deploy**
   - Upload `website/` and `public_assets/` to your static hosting provider (e.g. GitHub Pages, Netlify, Vercel, Firebase Hosting).
   - Example for GitHub Pages:
     ```bash
     # Push the website branch or configure Pages to serve from /website
     git subtree push --prefix website origin gh-pages
     ```

## Pre-Deployment Checklist
- [ ] All links resolve correctly.
- [ ] Images load and are properly sized.
- [ ] Page is mobile-responsive.
- [ ] Privacy policy and contact links are valid.
- [ ] Analytics / tracking script (if any) is configured.

## Related
- App download links on the website should point to the latest Play Store release.
- See `deploy-android.md` for building the Android app.
