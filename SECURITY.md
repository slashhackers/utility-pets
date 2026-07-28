# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ Yes    |

## Reporting a Vulnerability

If you discover a security vulnerability in **Utility Pet**, please report it **privately** by opening a [GitHub Security Advisory](https://github.com/slashhackers/utility-pets/security/advisories/new) rather than a public issue.

Please include:
- A description of the vulnerability
- Steps to reproduce it
- Potential impact
- Any suggested fixes

We will respond within **72 hours** and aim to release a patch within 7 days for critical issues.

---

## Security Architecture

### Network Exposure
- The **HTTP media server** binds to your **local LAN IP** only — it is **not** exposed to the internet.
- The server port is OS-assigned dynamically (ephemeral port range) and **not fixed**.
- All API endpoints (`/api/*`) are local-only and not protected by authentication — they are accessible to anyone on your local Wi-Fi network.

### Data Handling
- **No data is collected, logged, or transmitted** outside your local network.
- Video files are streamed **only** to the TV you select — not stored or cached.
- The only log file written is `/tmp/cast-to-tv.log`, which contains basic playback status.

### DLNA/UPnP Communication
- All DLNA SOAP commands are sent to devices discovered on your local subnet.
- The SOAP `SetAVTransportURI` command sends only the local stream URL — no file paths or metadata are sent to the TV.
- Input validation is applied on all API endpoints (seek time validated as `HH:MM:SS`).

### Install Script
- The `install.sh` script downloads only from **official GitHub Releases** — not from third-party CDNs.
- The SHA256 checksum file (`cast-to-tv-macos.tar.gz.sha256`) is published alongside every release for verification.

### Threat Model — Known Limitations

| Threat | Mitigated? | Notes |
|--------|-----------|-------|
| Remote code execution via network | ✅ No | Server only accessible on LAN |
| File path traversal via `/stream` | ✅ Fixed | `filePath` is resolved at startup, not per-request |
| Seek SOAP injection | ✅ Fixed | Time validated against `HH:MM:SS` regex |
| Malicious DLNA device on LAN | ⚠️ Partial | Trust is implicit for local UPnP devices |
| Unauthenticated API access | ⚠️ By design | Local-only, no auth — by design for simplicity |
| Process spawned by Automator | ✅ No | Uses `nohup` background process, no elevated privileges |
