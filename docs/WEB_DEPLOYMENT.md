# Web hosting preparation

The Flutter web target and Vercel configuration are included. This is hosting preparation, not authorization to expose the legacy backend publicly.

1. Complete the authentication, authorization and storage release gates in `PRODUCTION_CONFIGURATION.md` against staging first.
2. Import this repository into Vercel with Framework Preset **Other**. The committed `vercel.json` specifies the build command and `build/web` output. The build script downloads the pinned Flutter SDK if none is present, validates public client configuration, analyzes the app and builds it.
3. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` for the appropriate Vercel environment. Never set a service-role key for this build. Use a staging backend for Preview and do not enable public Production until the release gates pass.
4. Configure the approved domain and verify sign-in, session expiry, authorized evidence retrieval, browser camera/upload permissions and backend CORS in Preview. Account recovery/confirmation redirect URLs must be configured once the new authentication flow is implemented.
5. Run acceptance checks before approving a Production deployment. Vercel deployment/protection settings and DNS have not been configured by this task.

Local compilation: `flutter build web --release --no-pub`.
Local smoke test: `python -m http.server 8765 --bind 127.0.0.1 --directory build/web`.
An unconfigured build renders an explicit configuration warning and cannot sign in.

No hosting deployment was performed. The GitHub web workflow compiles an unconfigured bundle as a check; it does not publish it. Avoid a persistent service worker until shared-device account isolation and update/recovery behaviour have been accepted.

References: [Flutter web deployment](https://docs.flutter.dev/deployment/web), [Vercel build configuration](https://vercel.com/docs/builds/configure-a-build).
