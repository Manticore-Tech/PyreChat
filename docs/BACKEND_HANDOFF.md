# PyreChat backend handoff

## Verified backend ownership

The backend source is now present inside the workspace at:

`E:\Documents\Minecraft Modding\Projects\PyreChat\PyreChat`

This is the server currently designed to own `https://chat.pyrearms.dev`.
It is a Cloudflare stack, not an inferred provider:

- Hono API: `worker/api.ts`
- Worker entrypoint: `worker/index.ts`
- Cloudflare config: `wrangler.jsonc`
- D1 database binding: `DB` -> `pyrechat`
- R2 media binding: `MEDIA` -> `pyrechat-media`
- Durable Objects: `CHAT_ROOM` and `USER_HUB`
- custom Worker domain: `chat.pyrearms.dev`
- migrations: `migrations/`

Do not confuse this recovered full-stack/backend repository with the canonical
Flutter client at `PyreChat\pyrechat_flutter`. The nested backend repository
also contains older React/Capacitor/native client surfaces; those are preserved
but are not the active Flutter product UI.

## Server-synced profile photos

Profile-photo persistence is now implemented against the verified backend source.

Database:

- `migrations/0013_user_avatars.sql` adds `users.avatar_key`.

API:

- `PUT /api/me/avatar`
  - authenticated;
  - rate-limited;
  - accepts JPEG, PNG, or WebP only;
  - enforces a 5 MiB byte limit;
  - checks file signatures instead of trusting only the Content-Type header;
  - stores a dedicated `avatar/<userId>/<uuid>.<ext>` object in R2;
  - atomically points the user row at the new object;
  - removes the prior avatar object after a successful replacement;
  - returns the updated user object.
- `DELETE /api/me/avatar`
  - clears the user's avatar reference and removes the previous R2 object.
- `GET /api/avatar/:userId`
  - requires an authenticated PyreChat session;
  - refuses blocked viewer/target pairs;
  - serves only the target user's dedicated avatar object;
  - sends private caching and `nosniff` headers.

The public/current-user representation now returns `avatarUrl` when an avatar
exists. Search, friends, friend-add surfaces, and chat participant metadata also
return an `avatar_url` field.

The active Flutter client now:

- uploads its normalized profile JPEG with `PUT /api/me/avatar`;
- preserves the local image immediately as an offline/failure fallback;
- caches the updated returned user in `SessionStore`;
- resolves relative avatar URLs against `PYRE_API_ORIGIN`;
- includes the bearer token only for same-PyreChat-origin avatar requests;
- does not forward a bearer token to arbitrary third-party image URLs;
- renders remote avatars in profile, friend/search, and direct-chat surfaces.

The Flutter picker resizes/re-encodes selected profile images before upload.
The Worker independently verifies image type/signature and byte size. A later
production-hardening pass can add server-side decoded-dimension validation and
server-side re-encoding if arbitrary non-PyreChat clients are allowed to upload
avatars.

## Manual production deploy

Run these commands from:

`E:\Documents\Minecraft Modding\Projects\PyreChat\PyreChat`

First verify/build:

```powershell
npm ci
npm run build
```

Apply any new D1 migrations:

```powershell
npx wrangler d1 migrations apply pyrechat --remote
```

Deploy the Worker and web assets:

```powershell
npm run deploy
```

If Wrangler is not authenticated on the machine:

```powershell
npx wrangler login
```

Do **not** run `wrangler secret put SESSION_SECRET` as routine deployment.
That command changes the production secret and should only be used when the
secret is missing or intentionally being rotated.

For the current profile-photo change, migration `0013_user_avatars.sql` must
be applied before or as part of the Worker deployment.

## GitHub deployment path

The recovered repository also defines
`.github/workflows/deploy.yml`.

On a push to `master` (or manual workflow dispatch), that workflow:

1. uses Node 22;
2. requires the repository secret `CLOUDFLARE_API_TOKEN`;
3. runs `npm ci`;
4. applies remote D1 migrations with
   `npx wrangler d1 migrations apply pyrechat --remote`;
5. runs `npm run deploy`.

It also expects the GitHub repository variable `CLOUDFLARE_ACCOUNT_ID`.

The recovered README identifies the historical backend source repository as
`https://github.com/MaximusPyre/pyrechat`. The copied workspace directory
should not be assumed to retain Git metadata just because those workflow files
are present.

## Production verification after deploy

After deployment, verify in this order:

1. `GET /api/health`;
2. existing login/session restore;
3. `GET /api/me`;
4. upload a profile photo;
5. reload `/api/me` and confirm `avatarUrl` persists;
6. fetch the authenticated avatar URL;
7. replace the profile photo and confirm the old R2 object is no longer used;
8. remove the photo and confirm the profile falls back cleanly;
9. verify the avatar appears from a second authorized account in search/friends/chat;
10. verify a blocked account cannot fetch the avatar;
11. exercise existing snap/media upload and chat flows to catch regressions.

## Current verification boundary

The active Flutter client is fully green through the shared verification helper:

- `flutter analyze --no-pub` PASS;
- **75 tests passed / 1 intentional skip**;
- Android debug APK build PASS;
- Windows debug build PASS.

A direct `flutter test` invocation through the workspace-local Flutter checkout
can still hit the known native-assets path-with-spaces issue
(`E:\Documents\Minecraft ...`); the shared helper uses the working Flutter
installation and is the canonical local verification lane.

The helper has also been extended to run `npm ci` + `npm run build` against
the recovered backend during its comprehensive build. That backend compile has
not yet completed in this pass because the heavy-work lane was occupied when the
post-change helper rerun was requested.

No production migration or Worker deployment has been performed by this pass.
