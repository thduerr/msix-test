# Hello World MSIX

- `src/main.go` – the app (shows a "Hello, World!" message box)
- `pkg/AppxManifest.xml` – the MSIX package manifest
- `pack.py` – generates icons, AppxBlockMap.xml and [Content_Types].xml, and zips the package
- `build.sh` – builds the exe, packs, creates a self-signed cert (first run) and signs

Build: `./build.sh` (needs go, python3, openssl, osslsigncode).

Install on Windows (admin PowerShell):

    Import-Certificate -FilePath .\HelloWorld.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople
    Add-AppxPackage .\HelloWorld.msix

The Publisher in AppxManifest.xml must match the signing certificate's subject (CN=HelloWorld Dev).
