---
name: verify-release
description: Validate a published TransPaste GitHub release — assets, checksum, signature, version. Use right after the Release workflow finishes, or to audit an old release.
---

# Verify a published release

Run against `v<X.Y.Z>` (default: the latest release).

```bash
TAG=${1:-$(gh release list --limit 1 --json tagName --jq '.[0].tagName')}
V=${TAG#v}
DIR=$(mktemp -d)
gh release download "$TAG" --dir "$DIR"
```

Checks, all must pass:

1. **Assets**: exactly `TransPaste-$V.zip` and `TransPaste-$V.zip.sha256`.
2. **Checksum**: `cd "$DIR" && shasum -a 256 -c "TransPaste-$V.zip.sha256"`.
3. **Signature**: `ditto -x -k "TransPaste-$V.zip" . && codesign --verify --verbose TransPaste.app`.
4. **Version**: `plutil -p TransPaste.app/Contents/Info.plist | grep CFBundleShortVersionString` equals `$V`; also matches `Sources/AppInfo.swift` at that tag (`git show "$TAG:Sources/AppInfo.swift" | grep version`).
5. **Notes**: `gh release view "$TAG"` body contains the Installation footer
   (Gatekeeper instructions) and, if the bundle ID/signing changed in this
   release, an explicit permission re-grant warning.
6. **Launchability probe** (local only): `open TransPaste.app` and confirm the
   menu bar icon appears; quit after.

Report pass/fail per check. Any failure → fix and republish assets via
`gh release upload --clobber`, or for code problems delete the release + tag
and cut a patch release properly (see the `release` skill).
