# UniFi backup file (.unf) / support file (.supp) decryption

Decrypts legacy UniFi Network Controller `.unf` / `.supp` backup files and provides an API-based
alternative for newer UniFi OS appliances whose `.unifi` backups are not decryptable.

## Format support

| Format   | Tool support           | Notes                                                                |
|----------|------------------------|----------------------------------------------------------------------|
| `.unf`   | `decrypt.sh` (this repo) | Legacy UniFi Network Controller backup (pre-UniFi OS).               |
| `.supp`  | `decrypt.sh` (this repo) | UniFi Network Controller support file. Same AES key as `.unf`.       |
| `.unifi` | Not decryptable        | UniFi OS proprietary encryption (high entropy ≈1.0 bits/byte). No community tool decrypts this format. Use `scripts/api-export.sh` against a live controller instead. |

The `.unifi` format is what UniFi OS appliances (UDM, UDM-Pro, UDR, UDW, Cloud Gateway Ultra, etc.)
write to "Download Backup". This tool will not help you with those files. Capture structured
config via the Network API instead — see the API export section below.

## Installation

Clone the repository and ensure dependencies are available:

```text
git clone https://github.com/JacobPEvans/unifi-backup-decrypt.git
cd unifi-backup-decrypt
```

### Dependencies

For `.unf` / `.supp` decryption (`decrypt.sh`):

* `openssl`
* `zip`

For API export (`scripts/api-export.sh`):

* `curl`
* `jq`
* `bash` 4+

All dependencies are typically pre-installed on Linux and macOS, or available via your system
package manager.

## Usage

### Decrypting `.unf` / `.supp`

```text
./decrypt.sh input.unf output.zip
```

The output is a standard ZIP archive containing controller backup contents.

#### Some code snippet

```text
final Cipher instance = Cipher.getInstance("AES/CBC/NoPadding");
instance.init(2, new SecretKeySpec("bcyangkmluohmars".getBytes(), "AES"), new IvParameterSpec("ubntenterpriseap".getBytes()));
return new CipherInputStream(inputStream, instance);
```

Malformed zip files require fixing before unzip — `decrypt.sh` handles this via `zip -FF`.

#### Database

`db.gz` contains a stream of BSON documents for each collection of the `ace` database.

View its content with `gunzip -c db.gz | bsondump`.

### API export (for UniFi OS appliances)

For controllers running UniFi OS, decrypting the local backup is not an option. Instead, capture
the live config as structured JSON via the Network API:

```text
UNIFI_USER=admin UNIFI_PASS='...' scripts/api-export.sh \
  --host https://10.0.1.1 --site default --output-dir ./exports
```

This produces five JSON files suitable for version control:

| File                  | Endpoint            | Contents                          |
|-----------------------|---------------------|-----------------------------------|
| `networks.json`       | `rest/networkconf`  | VLANs, subnets, gateway config    |
| `firewall-rules.json` | `rest/firewallrule` | Firewall rule definitions         |
| `devices.json`        | `stat/device`       | APs, switches, gateways           |
| `wireless.json`       | `rest/wlanconf`     | SSIDs, security, VLAN binding     |
| `wan-config.json`     | `get/setting`       | WAN / failover configuration      |

Run `scripts/api-export.sh --help` for a quick reference.

#### Use case

Run `api-export.sh` from cron on any host inside the management network. Commit the resulting
`exports/` directory to a private git repository to get versioned diffs of your controller config
over time — including VLAN changes, firewall rule edits, and SSID configuration.

## API

`scripts/api-export.sh` authenticates against `/api/auth/login` (POST with JSON body
`{username, password}`), captures the session cookie and CSRF token from response headers, then
issues GET requests against the Network API proxy path
(`/proxy/network/api/s/<site>/...`) for each endpoint listed above.

TLS certificate verification is disabled (`curl -k`) because UDM/UDW controllers ship with a
self-signed certificate out of the box. Use this script only inside trusted internal networks.

### Environment variables

| Variable     | Required | Description                                        |
|--------------|----------|----------------------------------------------------|
| `UNIFI_USER` | yes      | Local admin username on the controller             |
| `UNIFI_PASS` | yes      | Password for `UNIFI_USER`                          |

### Flags

| Flag           | Default      | Description                                    |
|----------------|--------------|------------------------------------------------|
| `--host`       | (required)   | Controller URL, e.g. `https://10.0.1.1`        |
| `--site`       | `default`    | UniFi site name                                |
| `--output-dir` | `./exports`  | Where to write the five JSON files             |

## Contributing

PRs are welcome — particularly for:

* BSON import/export helpers for the decrypted `db.gz`
* Additional API endpoints worth versioning (e.g. user groups, port profiles)
* Reverse-engineering the `.unifi` format

Open an issue first for anything that changes the script CLI or output format.

## License

Apache-2.0. See [`LICENSE`](./LICENSE) for the full text.
