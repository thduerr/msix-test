#!/usr/bin/env bash
# Builds a signed, auto-updating HelloWorld MSIX release on Linux/macOS.
# Requires: go, python3, openssl, osslsigncode (2.6+)
#
# Usage: VERSION=1.0.1.0 BASE_URL=https://example.com/helloworld ./build.sh
#   VERSION  - package version (4 parts); raise it for every release
#   BASE_URL - where you will upload the files in release/ (HTTPS or a file share)
#   PACKAGE_BASE_URL - optional; where this version's .msix lives, if not BASE_URL
#   REQUIRE_CERT=1 - fail instead of creating a new certificate (used in CI)
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${VERSION:-1.0.0.0}"
BASE_URL="${BASE_URL:-https://example.com/helloworld}"
BASE_URL="${BASE_URL%/}"
PACKAGE_BASE_URL="${PACKAGE_BASE_URL:-$BASE_URL}"
PACKAGE_BASE_URL="${PACKAGE_BASE_URL%/}"
NAME="HelloWorld.Sample"
PUBLISHER="CN=HelloWorld Dev"
MSIX="HelloWorld_${VERSION}_x64.msix"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must look like 1.2.3.0"; exit 1; }

rm -rf build && mkdir -p build/pkg/Assets release
sed "s/Version=\"[0-9.]*\"/Version=\"$VERSION\"/" pkg/AppxManifest.xml > build/pkg/AppxManifest.xml
(cd src && GOOS=windows GOARCH=amd64 go build -ldflags "-H=windowsgui -s -w" -o ../build/pkg/HelloWorld.exe .)
python3 pack.py build/pkg build/unsigned.msix

if [ ! -f cert.pem ] || [ ! -f key.pem ]; then
  if [ "${REQUIRE_CERT:-0}" = 1 ]; then
    echo "cert.pem/key.pem missing; refusing to create a new certificate (updates would break)"; exit 1
  fi
  openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 730 -subj "/$PUBLISHER" \
    -addext "basicConstraints=critical,CA:FALSE" -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning"
fi
openssl x509 -in cert.pem -outform DER -out release/HelloWorld.cer
rm -f "release/$MSIX"
osslsigncode sign -certs cert.pem -key key.pem -in build/unsigned.msix -out "release/$MSIX"

# The .appinstaller file is what Windows polls for updates. Always overwrite it so it
# points at the newest package; keep its own Uri stable across releases.
cat > release/HelloWorld.appinstaller <<XML
<?xml version="1.0" encoding="utf-8"?>
<AppInstaller xmlns="http://schemas.microsoft.com/appx/appinstaller/2018"
  Version="$VERSION" Uri="$BASE_URL/HelloWorld.appinstaller">
  <MainPackage Name="$NAME" Publisher="$PUBLISHER" Version="$VERSION"
    ProcessorArchitecture="x64" Uri="$PACKAGE_BASE_URL/$MSIX" />
  <UpdateSettings>
    <!-- Check every time the app starts; install the update right away -->
    <OnLaunch HoursBetweenUpdateChecks="0" UpdateBlocksActivation="true" ShowPrompt="false" />
    <!-- Also check every ~8 hours in the background, even if the app isn't opened -->
    <AutomaticBackgroundTask />
  </UpdateSettings>
</AppInstaller>
XML

rm -rf build
echo "Built release/$MSIX and release/HelloWorld.appinstaller (version $VERSION)"
echo "Upload HelloWorld.appinstaller to $BASE_URL/ and $MSIX to $PACKAGE_BASE_URL/"
