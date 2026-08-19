#!/usr/bin/env bash
set -euo pipefail

# Repack KeepSolid VPN Unlimited 9.0.1 for Debian 13 (Trixie).
#
# The script downloads the original vendor package directly from the
# KeepSolid APT repository, verifies its SHA-256 checksum and package
# metadata, then changes Debian package metadata only.
#
# No VPN Unlimited application binaries are modified.
#
# Changes:
#   - Version: 9.0.1 -> 9.0.1+trixie1
#   - Removes obsolete dependency:
#       libqt5webkit5 (>= 5.15.3)
#   - Removes obsolete dependency alternative:
#       libllvm13 | libllvm14 | libllvm15
#
# The original package itself is not redistributed by this script.

readonly UPSTREAM_URL="http://apt.keepsolid.com/debian/dists/bookworm/main/binary-amd64/vpn-unlimited_9.0.1-amd64.deb"
readonly UPSTREAM_SHA256="27e490e6528e776c7d06ec32db5d91edb4f973991043cc49a43f6e0d98150068"

readonly EXPECTED_PACKAGE="vpn-unlimited"
readonly EXPECTED_VERSION="9.0.1"
readonly EXPECTED_ARCH="amd64"

readonly REPACK_VERSION="9.0.1+trixie1"
readonly OUTPUT_NAME="vpn-unlimited_${REPACK_VERSION}_amd64.deb"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for cmd in dpkg-deb python3 sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

if command -v curl >/dev/null 2>&1; then
    download() {
        curl --fail --location --show-error --silent \
            --output "$2" "$1"
    }
elif command -v wget >/dev/null 2>&1; then
    download() {
        wget --quiet --output-document="$2" "$1"
    }
else
    die "Neither curl nor wget is installed"
fi

output_dir="${1:-.}"
mkdir -p "$output_dir"
output_dir="$(readlink -f -- "$output_dir")"
output_deb="${output_dir}/${OUTPUT_NAME}"

[[ ! -e "$output_deb" ]] || die "Output file already exists: $output_deb"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

upstream_deb="${workdir}/vpn-unlimited_9.0.1-amd64.deb"
package_dir="${workdir}/package"

echo "Downloading upstream package:"
echo "  ${UPSTREAM_URL}"
download "$UPSTREAM_URL" "$upstream_deb"

echo "Verifying upstream SHA-256..."
actual_sha256="$(sha256sum "$upstream_deb" | awk '{print $1}')"
[[ "$actual_sha256" == "$UPSTREAM_SHA256" ]] || {
    echo "Expected: $UPSTREAM_SHA256" >&2
    echo "Actual:   $actual_sha256" >&2
    die "Upstream package checksum mismatch"
}

package="$(dpkg-deb -f "$upstream_deb" Package)"
version="$(dpkg-deb -f "$upstream_deb" Version)"
arch="$(dpkg-deb -f "$upstream_deb" Architecture)"

[[ "$package" == "$EXPECTED_PACKAGE" ]] \
    || die "Unexpected package '$package' (expected '$EXPECTED_PACKAGE')"
[[ "$version" == "$EXPECTED_VERSION" ]] \
    || die "Unexpected version '$version' (expected '$EXPECTED_VERSION')"
[[ "$arch" == "$EXPECTED_ARCH" ]] \
    || die "Unexpected architecture '$arch' (expected '$EXPECTED_ARCH')"

echo "Verified upstream package:"
echo "  Package:      $package"
echo "  Version:      $version"
echo "  Architecture: $arch"

dpkg-deb -R "$upstream_deb" "$package_dir"

control="${package_dir}/DEBIAN/control"
[[ -f "$control" ]] || die "Missing DEBIAN/control after extraction"

python3 - "$control" "$REPACK_VERSION" <<'PY'
from pathlib import Path
import re
import sys

control_path = Path(sys.argv[1])
new_version = sys.argv[2]

text = control_path.read_text(encoding="utf-8")

expected_old_version = "9.0.1"
dependencies_to_remove = {
    "libqt5webkit5 (>= 5.15.3)",
    "libllvm13 | libllvm14 | libllvm15",
}


def get_field(source: str, name: str) -> tuple[re.Match[str], str]:
    pattern = re.compile(
        rf"(?m)^{re.escape(name)}:[^\n]*(?:\n[ \t][^\n]*)*"
    )
    match = pattern.search(source)
    if not match:
        raise SystemExit(f"ERROR: Missing {name}: field in DEBIAN/control")
    return match, match.group(0)


# Update Version.
match, version_field = get_field(text, "Version")
if version_field != f"Version: {expected_old_version}":
    raise SystemExit(
        f"ERROR: Unexpected Version field: {version_field!r}"
    )

text = (
    text[:match.start()]
    + f"Version: {new_version}"
    + text[match.end():]
)

# Remove only the two explicitly verified obsolete runtime dependencies.
match, depends_field = get_field(text, "Depends")

depends_value = depends_field[len("Depends:"):].replace("\n", " ").strip()
dependencies = [item.strip() for item in depends_value.split(",")]

missing = dependencies_to_remove.difference(dependencies)
if missing:
    raise SystemExit(
        "ERROR: Expected dependencies not found: "
        + ", ".join(sorted(missing))
    )

dependencies = [
    item for item in dependencies
    if item not in dependencies_to_remove
]

new_depends_field = "Depends: " + ", ".join(dependencies)

text = (
    text[:match.start()]
    + new_depends_field
    + text[match.end():]
)

control_path.write_text(text, encoding="utf-8")
PY

echo
echo "Repacked package metadata:"
grep -E '^(Package|Version|Architecture|Depends|Recommends):' "$control"

echo
echo "Building:"
echo "  $output_deb"

dpkg-deb --build --root-owner-group "$package_dir" "$output_deb" >/dev/null

# Verify the generated package metadata.
[[ "$(dpkg-deb -f "$output_deb" Package)" == "$EXPECTED_PACKAGE" ]] \
    || die "Generated package has unexpected Package field"
[[ "$(dpkg-deb -f "$output_deb" Version)" == "$REPACK_VERSION" ]] \
    || die "Generated package has unexpected Version field"
[[ "$(dpkg-deb -f "$output_deb" Architecture)" == "$EXPECTED_ARCH" ]] \
    || die "Generated package has unexpected Architecture field"

if dpkg-deb -f "$output_deb" Depends \
    | grep -Eq 'libqt5webkit5|libllvm13|libllvm14|libllvm15'; then
    die "Generated package still contains an obsolete dependency"
fi

echo
echo "Done."
echo "Output:"
echo "  $output_deb"
echo "SHA-256:"
sha256sum "$output_deb"


echo
if [[ -t 0 ]]; then
    read -r -p "Install the generated package now using apt? [y/N] " answer
    case "$answer" in
        y|Y|yes|YES|Yes)
            if [[ $EUID -eq 0 ]]; then
                apt install "$output_deb"
            elif command -v sudo >/dev/null 2>&1; then
                sudo apt install "$output_deb"
            else
                die "Installation requires root privileges and sudo is not available"
            fi

            echo
            echo "Note:"
            echo "The upstream VPN Unlimited post-install script may print:"
            echo
            echo "  Failed to restart ipsec.service: Unit ipsec.service not found."
            echo "  invoke-rc.d: initscript ipsec, action \"restart\" failed."
            echo "  Unit ipsec.service could not be found."
            echo
            echo "This is expected on Debian 13 (Trixie) with the current strongSwan"
            echo "charon-systemd/swanctl setup and does not indicate that the VPN"
            echo "Unlimited installation failed."
            ;;
        *)
            echo "Installation skipped."
            ;;
    esac
else
    echo "Non-interactive input detected; installation skipped."
fi
