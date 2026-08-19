# VPN Unlimited tools for Debian

This directory contains helper scripts related to **KeepSolid VPN Unlimited** on Debian.

Different files in this directory may serve different purposes, target different VPN Unlimited versions, or target different Debian releases. Always read the description of the particular script before running it.

> **Important:** These scripts are community compatibility helpers. They are not provided, supported, or endorsed by KeepSolid.

## Available scripts

### `repack-vpn-unlimited_9.0.1-for-trixie.sh`

Creates a Debian 13 (Trixie) compatible repack of the upstream **VPN Unlimited 9.0.1 amd64** Debian package.

The original upstream package declares two obsolete dependencies that are not available in Debian 13:

- `libqt5webkit5 (>= 5.15.3)`
- `libllvm13 | libllvm14 | libllvm15`

Inspection of the VPN Unlimited 9.0.1 binaries showed that these libraries are not referenced by the shipped ELF binaries, are not referenced by the bundled text/QML files, and are not requested by name for dynamic loading.

The script therefore changes **Debian package metadata only**:

- downloads the original VPN Unlimited 9.0.1 package directly from the KeepSolid package repository;
- verifies the expected SHA-256 checksum;
- verifies the package name, version, and architecture;
- removes only the two obsolete dependency declarations listed above;
- changes the package version from `9.0.1` to `9.0.1+trixie1`;
- rebuilds the Debian package;
- verifies the resulting package metadata;
- optionally installs the generated package using `apt`.

No VPN Unlimited application binary is modified by the script.

## Requirements

The script is intended for:

- Debian 13 (Trixie);
- `amd64` / x86-64 systems;
- VPN Unlimited 9.0.1.

The following common tools must be available:

- `bash`
- `dpkg-deb`
- `python3`
- `sha256sum`
- either `curl` or `wget`

For the optional installation step, `apt` must be available. If the script is not run as `root`, `sudo` is also required for installation.

On a normal Debian 13 desktop installation, most or all of these tools will already be present.

## Installation and usage

The following instructions are intentionally detailed so that they can also be followed by users with little Linux command-line experience.

### 1. Open a terminal

On KDE Plasma, for example, open **Konsole**.

### 2. Go to the directory containing the script

If you cloned the whole `pub.tool.CustomBuilds` repository, change into this directory.

For example:

```bash
cd pub.tool.CustomBuilds/debian/network/vpn-unlimited
```

Use the actual path where you cloned the repository if it is different.

### 3. Make the script executable

This only needs to be done once:

```bash
chmod +x repack-vpn-unlimited_9.0.1-for-trixie.sh
```

### 4. Run the script

Run:

```bash
./repack-vpn-unlimited_9.0.1-for-trixie.sh
```

The script will:

1. download the original VPN Unlimited 9.0.1 package from KeepSolid;
2. verify that it is exactly the expected upstream package;
3. unpack it into a temporary working directory;
4. modify only its Debian dependency metadata;
5. rebuild it as:

```text
vpn-unlimited_9.0.1+trixie1_amd64.deb
```

6. print the SHA-256 checksum of the generated package.

Temporary build files are automatically removed when the script finishes.

### 5. Optional: install the generated package

At the end, the script asks:

```text
Install the generated package now using apt? [y/N]
```

To install it immediately, type:

```text
y
```

and press **Enter**.

Typing anything else, or simply pressing **Enter**, skips installation.

If the script is running as a normal user, it will use `sudo apt install ...` and may ask for your password.

If you skip installation, you can install the generated package later manually:

```bash
sudo apt install ./vpn-unlimited_9.0.1+trixie1_amd64.deb
```

If you are already logged in as `root`, omit `sudo`:

```bash
apt install ./vpn-unlimited_9.0.1+trixie1_amd64.deb
```

## Choosing a different output directory

By default, the generated `.deb` file is placed in the current directory.

You may optionally pass another directory as the first argument:

```bash
./repack-vpn-unlimited_9.0.1-for-trixie.sh ./dist
```

The package will then be created as:

```text
./dist/vpn-unlimited_9.0.1+trixie1_amd64.deb
```

The script refuses to overwrite an existing output package.

## Known installation message about `ipsec.service`

During installation, the original VPN Unlimited post-installation script may print:

```text
Failed to restart ipsec.service: Unit ipsec.service not found.
invoke-rc.d: initscript ipsec, action "restart" failed.
Unit ipsec.service could not be found.
```

On Debian 13 with the current strongSwan `charon-systemd` / `swanctl` setup, this message is expected and does **not** by itself mean that VPN Unlimited installation failed.

The upstream VPN Unlimited 9.0.1 installer still attempts to restart the older `ipsec.service` interface.

A successful installation can be checked with:

```bash
dpkg -s vpn-unlimited | grep -E '^(Status|Version):'
```

Expected output includes:

```text
Status: install ok installed
Version: 9.0.1+trixie1
```

The VPN Unlimited daemon can also be checked with:

```bash
systemctl status vpn-unlimited-daemon --no-pager
```

A working installation should normally show:

```text
Active: active (running)
```

Ultimately, the most useful test is to start the VPN Unlimited GUI and establish a real VPN connection.

## What the script does not do

The script does **not**:

- redistribute the original KeepSolid `.deb` package;
- modify VPN Unlimited executable binaries or shared libraries;
- disable Debian package signature or dependency checking globally;
- add Debian 12 (Bookworm) repositories to a Debian 13 system;
- install obsolete QtWebKit or LLVM 13/14/15 packages;
- change unrelated system packages.

The original package is downloaded directly from KeepSolid when the script is run.

## Upstream package verification

The script currently expects the upstream package:

```text
Package: vpn-unlimited
Version: 9.0.1
Architecture: amd64
```

and verifies this SHA-256 checksum:

```text
27e490e6528e776c7d06ec32db5d91edb4f973991043cc49a43f6e0d98150068
```

If KeepSolid changes the file at the upstream URL, or publishes a different package under the same location, the script will stop instead of silently repacking an unexpected file.

This is intentional.

## Why the repacked version is named `9.0.1+trixie1`

The application itself is still upstream VPN Unlimited 9.0.1.

The `+trixie1` suffix indicates that this is a local Debian 13 compatibility repack with adjusted package metadata.

This also allows Debian package management to distinguish it from the original upstream `9.0.1` package.

## Updating or adding scripts

This directory may contain additional VPN Unlimited compatibility helpers in the future.

When adding another script, prefer a descriptive filename that includes the relevant upstream version and, where appropriate, the target Debian release.

For example:

```text
repack-vpn-unlimited_<upstream-version>-for-<debian-release>.sh
```

Each script should document its assumptions and should make the smallest practical change required for compatibility.
