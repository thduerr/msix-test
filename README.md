# Hello World MSIX (with auto-update)

- `src/main.go` – the app (shows "Hello, World!" and its installed version)
- `pkg/AppxManifest.xml` – the MSIX package manifest (version is set by build.sh)
- `pack.py` – generates icons, AppxBlockMap.xml and [Content_Types].xml, and zips the package
- `build.sh` – builds the exe, packs, signs, and writes the `.appinstaller` update file

## Build a release

    VERSION=1.0.0.0 BASE_URL=https://your-server/helloworld ./build.sh

Needs go, python3, openssl, osslsigncode. Output goes to `release/`. Upload
`HelloWorld.appinstaller` and the new `.msix` to BASE_URL.
The first run creates `cert.pem`/`key.pem`: keep them, every release must be signed with the same certificate.

## Install (once, on each PC, admin PowerShell)

    Import-Certificate -FilePath .\HelloWorld.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople
    Add-AppxPackage -AppInstallerFile https://your-server/helloworld/HelloWorld.appinstaller

Install from the `.appinstaller` file, not the `.msix` directly, or Windows won't know where to look for updates.

## Ship an update

1. Raise VERSION (e.g. 1.0.1.0) and run build.sh with the same BASE_URL.
2. Upload the new `.msix` and the overwritten `HelloWorld.appinstaller`.

Windows checks at every app launch and about every 8 hours in the background, and installs the new version automatically.

## Automatic releases with GitHub Actions

`.github/workflows/release.yml` builds and publishes a release whenever you push a tag
like `v1.2.3` (becomes version 1.2.3.0) or `v1.2.3.4`.

One-time setup (keep using the same certificate forever, or installed apps stop updating):

    gh secret set SIGNING_CERT_PEM < cert.pem
    gh secret set SIGNING_KEY_PEM  < key.pem

Optional: set the repository variable `BASE_URL` (Settings → Secrets and variables → Actions → Variables)
to host updates on your own server. Without it, files are served from GitHub Releases and users install with:

    Add-AppxPackage -AppInstallerFile https://github.com/OWNER/REPO/releases/latest/download/HelloWorld.appinstaller

Release:

    git tag v1.0.1 && git push origin v1.0.1
