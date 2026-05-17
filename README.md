# UniFi backup file (.unf) / support file (.supp) decryption

Decrypts legacy UniFi Network Controller `.unf` / `.supp` backup files and provides two API-based
alternatives for newer UniFi OS appliances whose `.unifi` backups are not decryptable.

## Format support

| Format   | Tool support             | Notes                                                                |
|----------|--------------------------|----------------------------------------------------------------------|
| `.unf`   | `decrypt.sh` (this repo) | Legacy UniFi Network Controller backup (pre-UniFi OS).               |
| `.supp`  | `decrypt.sh` (this repo) | UniFi Network Controller support file. Same AES key as `.unf`.       |
| `.unifi` | Not decryptable          | UniFi OS proprietary encryption (high entropy ≈1.0 bits/byte). No community tool decrypts this format. Use one of the `scripts/*-export.sh` exporters against a live controller instead. |

The `.unifi` format is what UniFi OS appliances (UDM, UDM-Pro, UDR, UDW, Cloud Gateway Ultra, etc.)
write to "Download Backup". This tool will not help you with those files. Capture structured
config via the API instead — see the export sections below.

## Two API export modes

| Script                       | Auth                              | Scope                                                                              | Best for                                       |
|------------------------------|-----------------------------------|------------------------------------------------------------------------------------|------------------------------------------------|
| `scripts/api-export.sh`      | Controller `username`/`password`  | Full local Network API: VLANs, firewall rules, WLAN, WAN/failover, device state    | You have a local admin user on the controller  |
| `scripts/cloud-export.sh`    | UI Cloud `X-API-KEY`              | Sites, hosts (incl. `reportedState`), devices, ISP/WAN metrics, SD-WAN configs     | UniFi OS appliances managed via account.ui.com |

The two scripts are complementary, not redundant. The cloud script gives you a working snapshot
when only a UI Cloud API key is available — common for UniFi OS hardware where many users never
create a local admin user. The local script returns the actual VLAN / firewall / WLAN
configuration objects, which the cloud API does not expose.

Run both if you have both credentials; the output filenames do not collide.

## Installation

```text
git clone https://github.com/JacobPEvans/unifi-backup-decrypt.git
cd unifi-backup-decrypt
```

### Dependencies

For `.unf` / `.supp` decryption (`decrypt.sh`):

* `openssl`
* `zip`

For either API exporter:

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

### Local Network API export (`api-export.sh`)

For controllers reachable on your LAN where you have a local admin user, capture the live
config as structured JSON via the Network API:

```text
UNIFI_USER=admin UNIFI_PASS='...' scripts/api-export.sh \
  --host https://10.0.1.1 --site default --output-dir ./exports
```

Five JSON files land in `exports/`:

| File                  | Endpoint            | Contents                          |
|-----------------------|---------------------|-----------------------------------|
| `networks.json`       | `rest/networkconf`  | VLANs, subnets, gateway config    |
| `firewall-rules.json` | `rest/firewallrule` | Firewall rule definitions         |
| `devices.json`        | `stat/device`       | APs, switches, gateways           |
| `wireless.json`       | `rest/wlanconf`     | SSIDs, security, VLAN binding     |
| `wan-config.json`     | `get/setting`       | WAN / failover configuration      |

Run `scripts/api-export.sh --help` for a quick reference.

### Cloud Site Manager API export (`cloud-export.sh`)

For UniFi OS appliances, the easiest credential is usually a UI Cloud API key from
[account.ui.com → Site Manager → API Keys](https://account.ui.com/). With that key:

```text
UNIFI_API_KEY='...' scripts/cloud-export.sh --output-dir ./exports
```

Six JSON files land in `exports/` (different filenames so this does not clash with
`api-export.sh` output):

| File                    | Endpoint                          | Contents                                       |
|-------------------------|-----------------------------------|------------------------------------------------|
| `sites.json`            | `/ea/sites`                       | Sites visible to the API key                   |
| `hosts.json`            | `/ea/hosts`                       | All console hosts (UDM, UDW, etc.)             |
| `host-details.json`     | `/ea/hosts/<id>` per host         | Detailed `reportedState` per console           |
| `devices.json`          | `/ea/devices?hostIds[]=...`       | APs / switches / gateways grouped by host      |
| `isp-metrics.json`      | `/ea/isp-metrics/5m`              | WAN throughput, latency, packet loss, ISP info |
| `sd-wan-configs.json`   | `/ea/sd-wan-configs`              | SD-WAN configs (empty list if none)            |

Run `scripts/cloud-export.sh --help` for a quick reference.

#### Use case

Either exporter is suitable for cron on a host inside the management network. Commit the
resulting `exports/` directory to a private git repository to get versioned diffs of your
controller config and device inventory over time.

## API

### Local Network API

`scripts/api-export.sh` authenticates against `/api/auth/login` (POST with JSON body
`{username, password}`), captures the session cookie and CSRF token from response headers, then
issues GET requests against the Network API proxy path (`/proxy/network/api/s/<site>/...`) for
each endpoint listed above.

TLS certificate verification is disabled (`curl -k`) because UDM/UDW controllers ship with a
self-signed certificate out of the box. Use this script only inside trusted internal networks.

#### Environment variables

| Variable     | Required | Description                                        |
|--------------|----------|----------------------------------------------------|
| `UNIFI_USER` | yes      | Local admin username on the controller             |
| `UNIFI_PASS` | yes      | Password for `UNIFI_USER`                          |

#### Flags

| Flag           | Default      | Description                                    |
|----------------|--------------|------------------------------------------------|
| `--host`       | (required)   | Controller URL, e.g. `https://10.0.1.1`        |
| `--site`       | `default`    | UniFi site name                                |
| `--output-dir` | `./exports`  | Where to write the five JSON files             |

### Cloud Site Manager API

`scripts/cloud-export.sh` sends an `X-API-KEY` header against `https://api.ui.com/ea/...`.
Reference docs: [developer.ui.com/site-manager-api](https://developer.ui.com/site-manager-api/).
TLS verification is enabled (this is a public CA-signed endpoint).

#### Environment variables

| Variable           | Required | Description                                                              |
|--------------------|----------|--------------------------------------------------------------------------|
| `UNIFI_API_KEY`    | yes      | UI Cloud API key from account.ui.com → Site Manager → API Keys           |

#### Flags

| Flag           | Default                       | Description                              |
|----------------|-------------------------------|------------------------------------------|
| `--output-dir` | `./exports`                   | Where to write the six JSON files        |
| `--base-url`   | `https://api.ui.com/ea`       | Override the API base URL (e.g. staging) |

## Contributing

PRs are welcome — particularly for:

* BSON import/export helpers for the decrypted `db.gz`
* Additional API endpoints worth versioning (e.g. user groups, port profiles)
* Reverse-engineering the `.unifi` format

Open an issue first for anything that changes the script CLI or output format.

## License

Apache-2.0. See [`LICENSE`](./LICENSE) for the full text.
