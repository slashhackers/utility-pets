# Development and release workflow

## Local development

```bash
./Scripts/build-app.sh debug
./Scripts/install-app.sh
```

The build script creates an ad-hoc-signed native `.app` bundle. The installed, running app provides **Cast with Scooby** as a native Finder service. Finder shows the service for file selections; the app accepts MP4 files only and reports an error for any other type.

## Signed and notarized release

An Apple Developer Program membership, Developer ID Application certificate, and a notarytool keychain profile are required.

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="utility-pets-notary"
./Scripts/release.sh
```

The release script signs with the hardened runtime, submits to Apple’s notary service, staples the ticket, and runs a Gatekeeper assessment.
