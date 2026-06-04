# Distributing DiskSpace as a free tool

This guide takes DiskSpace from source to a **signed + notarized `.dmg`** that
anyone can download and run without Gatekeeper warnings. It's free software, but
Apple still requires code signing + notarization for distribution outside the
App Store.

## What only you can do

These steps need your identity and a paid account — they can't be automated for
you:

1. **Apple Developer Program membership** — $99/year, at
   <https://developer.apple.com/programs/>. Required even for free apps, because
   notarization and Developer ID certificates are gated behind it.

2. **Developer ID Application certificate.** In Xcode: *Settings → Accounts →
   your team → Manage Certificates → +  → Developer ID Application*. Or create it
   at <https://developer.apple.com/account/resources/certificates>. It installs
   into your login keychain. Find its exact name with:
   ```sh
   security find-identity -v -p codesigning
   # → "Developer ID Application: Your Name (AB12CD34EF)"
   ```

3. **Notary credentials.** Create an app-specific password at
   <https://appleid.apple.com> (Sign-In & Security → App-Specific Passwords),
   then store a reusable notarytool profile:
   ```sh
   xcrun notarytool store-credentials "diskspace" \
       --apple-id "you@example.com" \
       --team-id "AB12CD34EF" \
       --password "abcd-efgh-ijkl-mnop"
   ```

## Build the release

With the above in place:

```sh
export DEVELOPER_ID_APP="Developer ID Application: Your Name (AB12CD34EF)"
export NOTARY_PROFILE="diskspace"
scripts/release.sh
```

`release.sh` builds the release binary, assembles `DiskSpace.app`, signs it with
your Developer ID under the **hardened runtime**, packages a drag-to-install DMG,
submits it to Apple's notary service (waits for the result), staples the ticket,
and verifies Gatekeeper acceptance. Output: `dist/DiskSpace-1.1.dmg`.

## Verify

```sh
spctl -a -vvv -t install dist/DiskSpace-1.1.dmg     # should say "accepted / Notarized Developer ID"
xcrun stapler validate dist/DiskSpace-1.1.dmg
```

## Publish

- **GitHub Releases** (simplest): tag a version, create a release, and attach
  `dist/DiskSpace-1.1.dmg`. Link it from the README.
- Or host the DMG on any static site/CDN.

Because the build is notarized and stapled, it verifies **offline** — users who
download it just open the DMG and drag the app to Applications.

## Why not the Mac App Store?

DiskSpace scans the entire disk and deletes arbitrary files. The App Store
sandbox forbids both — a sandboxed build could only touch user-picked folders,
which would gut the core feature. Developer ID + notarization is the right
channel for this tool. (App Store distribution would be a separate, reduced
build.)

## Local personal install

For just running it on your own Mac (no Apple account needed), use
`scripts/package.sh` — it ad-hoc signs and installs to `/Applications`.
