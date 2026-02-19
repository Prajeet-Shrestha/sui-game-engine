#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# upgrade.sh — Upgrade all Sui Game Engine packages in order:
#   1. entity  2. components  3. systems  4. world
#
# Reads SUI_NETWORK and MNEMONIC from .env
# Reads upgrade-capability IDs from each package's Published.toml
# Updates Move.toml published-at / addresses after each upgrade
# Logs each new package ID into package.ts as an exported object
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Load .env ──
if [ ! -f .env ]; then
  echo "❌ .env file not found. Copy .env.example → .env and fill in values."
  exit 1
fi
set -a
source .env
set +a

# ── Validate env ──
if [ -z "${SUI_NETWORK:-}" ]; then
  echo "❌ SUI_NETWORK not set in .env"
  exit 1
fi
if [ -z "${MNEMONIC:-}" ]; then
  echo "❌ MNEMONIC not set in .env"
  exit 1
fi

echo "═══════════════════════════════════════════════════════"
echo "  Sui Game Engine — Package Upgrader"
echo "  Network: $SUI_NETWORK"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── Import wallet from mnemonic ──
echo "🔑 Importing deployer wallet..."
sui keytool import "$MNEMONIC" ed25519 --json 2>/dev/null || true

# Set active env
sui client switch --env "$SUI_NETWORK" 2>/dev/null || {
  sui client new-env --alias "$SUI_NETWORK" --rpc "https://fullnode.${SUI_NETWORK}.sui.io:443"
  sui client switch --env "$SUI_NETWORK"
}

DEPLOYER_ADDRESS=$(sui client active-address)
echo "📍 Deployer address: $DEPLOYER_ADDRESS"
echo ""

# ── Helper: extract upgrade-capability from Published.toml ──
get_upgrade_cap() {
  local pkg_dir="$1"
  local pkg_name="$2"
  local published_toml="$pkg_dir/Published.toml"

  if [ ! -f "$published_toml" ]; then
    echo "❌ $published_toml not found for $pkg_name."
    echo "   Has this package been deployed with 'sui client publish'?"
    exit 1
  fi

  local cap
  cap=$(grep 'upgrade-capability' "$published_toml" | head -1 | sed 's/.*= *"\(.*\)"/\1/')

  if [ -z "$cap" ]; then
    echo "❌ Could not find upgrade-capability in $published_toml"
    exit 1
  fi

  echo "$cap"
}

# ── Read upgrade caps from Published.toml ──
echo "🔍 Reading upgrade capabilities from Published.toml files..."
UPGRADE_CAP_ENTITY=$(get_upgrade_cap "./entity" "entity")
UPGRADE_CAP_COMPONENTS=$(get_upgrade_cap "./components" "components")
UPGRADE_CAP_SYSTEMS=$(get_upgrade_cap "./systems" "systems")
UPGRADE_CAP_WORLD=$(get_upgrade_cap "./world" "world")
echo "   entity:     $UPGRADE_CAP_ENTITY"
echo "   components: $UPGRADE_CAP_COMPONENTS"
echo "   systems:    $UPGRADE_CAP_SYSTEMS"
echo "   world:      $UPGRADE_CAP_WORLD"
echo ""

# ── Clean stale build artifacts ──
echo "🧹 Cleaning build artifacts..."
PACKAGES=("entity" "components" "systems" "world")
for pkg in "${PACKAGES[@]}"; do
  rm -rf "./${pkg}/build"
done
echo "   Done."
echo ""

# ── Temp file for upgrade output ──
TMPJSON=$(mktemp /tmp/sui-upgrade-XXXXXX.json)
trap "rm -f $TMPJSON" EXIT

# ── Helper: upgrade a package and extract its new package ID ──
upgrade_package() {
  local pkg_name="$1"
  local pkg_dir="$2"
  local upgrade_cap="$3"

  echo "────────────────────────────────────────────────────"
  echo "📦 Upgrading: $pkg_name"
  echo "   Directory:   $pkg_dir"
  echo "   UpgradeCap:  $upgrade_cap"
  echo "────────────────────────────────────────────────────"

  # Upgrade — stdout (JSON) goes to temp file, stderr (warnings) to terminal
  if ! sui client upgrade "$pkg_dir" \
    --gas-budget 500000000 \
    --upgrade-capability "$upgrade_cap" \
    --skip-dependency-verification \
    --json > "$TMPJSON" 2>&1; then

    # Command failed — check if TMPJSON has valid JSON (sometimes sui
    # writes JSON even when returning non-zero exit code)
    if jq -e '.effects' "$TMPJSON" >/dev/null 2>&1; then
      echo "⚠️  sui client upgrade returned non-zero but JSON looks valid, continuing..." >&2
    else
      echo "❌ 'sui client upgrade' command failed for $pkg_name"
      cat "$TMPJSON"
      return 1
    fi
  fi

  # ── Extract status ──
  local clean_json
  clean_json=$(sed -n '/^{/,$ p' "$TMPJSON")

  if [ -z "$clean_json" ]; then
    echo "❌ No JSON found in upgrade output for $pkg_name"
    cat "$TMPJSON"
    return 1
  fi

  # Check status — handle both flat (.effects.status) and V2 (.effects.V2.status) formats
  local status
  status=$(echo "$clean_json" | jq -r '
    (if .effects.V2.status then
       (.effects.V2.status | if type == "string" then . else "Success" end)
     elif .effects.status.status then
       .effects.status.status
     else
       "unknown"
     end)
  ' 2>/dev/null) || status=""

  # Normalize case
  status=$(echo "$status" | tr '[:upper:]' '[:lower:]')

  if [ "$status" != "success" ]; then
    echo "❌ Upgrade failed for $pkg_name (status: $status)"
    echo "$clean_json" | jq '.effects' 2>/dev/null || echo "$clean_json"
    return 1
  fi

  # ── Extract new package ID — try multiple JSON formats ──
  local package_id=""

  # Format 1: objectChanges[] (newer Sui CLI)
  package_id=$(echo "$clean_json" | jq -r '
    [.objectChanges // [] | .[] | select(.type == "published") | .packageId] | first // empty
  ' 2>/dev/null) || true

  # Format 2: changed_objects[] with objectType "package" (Sui CLI 1.65)
  if [ -z "$package_id" ]; then
    package_id=$(echo "$clean_json" | jq -r '
      [.changed_objects // [] | .[] | select(.objectType == "package") | .objectId] | first // empty
    ' 2>/dev/null) || true
  fi

  # Format 3: effects.V2.changed_objects — array of [id, details] pairs
  if [ -z "$package_id" ]; then
    package_id=$(echo "$clean_json" | jq -r '
      [.effects.V2.changed_objects // [] | .[] | select(.[1].output_state.PackageWrite) | .[0]] | first // empty
    ' 2>/dev/null) || true
  fi

  if [ -z "$package_id" ]; then
    echo "❌ Could not extract package ID from upgrade output for $pkg_name"
    echo "$clean_json" | jq '{objectChanges, changed_objects}' 2>/dev/null || echo "$clean_json"
    return 1
  fi

  echo "✅ $pkg_name upgraded: $package_id"
  echo ""

  # Return package ID via a global variable (avoid stdout capture issues)
  LAST_PACKAGE_ID="$package_id"
}

# ── Helper: update a package's Move.toml after upgrading ──
update_published() {
  local pkg_dir="$1"
  local pkg_name="$2"
  local new_package_id="$3"
  local toml="$pkg_dir/Move.toml"

  # Update published-at to the new package ID
  sed -i '' "s|^published-at = \".*\"|published-at = \"${new_package_id}\"|" "$toml"

  # Update the package's own address in [addresses]
  sed -i '' "s|^${pkg_name} = \"0x[a-fA-F0-9]*\"|${pkg_name} = \"${new_package_id}\"|" "$toml"
}

# ═══════════════════════════════════════════════════════
#  Upgrade in dependency order
# ═══════════════════════════════════════════════════════

# 1. Entity (no dependencies)
upgrade_package "entity" "./entity" "$UPGRADE_CAP_ENTITY"
ENTITY_ID="$LAST_PACKAGE_ID"
update_published "./entity" "entity" "$ENTITY_ID"

# 2. Components (depends on entity)
upgrade_package "components" "./components" "$UPGRADE_CAP_COMPONENTS"
COMPONENTS_ID="$LAST_PACKAGE_ID"
update_published "./components" "components" "$COMPONENTS_ID"

# 3. Systems (depends on entity, components)
upgrade_package "systems" "./systems" "$UPGRADE_CAP_SYSTEMS"
SYSTEMS_ID="$LAST_PACKAGE_ID"
update_published "./systems" "systems" "$SYSTEMS_ID"

# 4. World (depends on entity, components, systems)
upgrade_package "world" "./world" "$UPGRADE_CAP_WORLD"
WORLD_ID="$LAST_PACKAGE_ID"
update_published "./world" "world" "$WORLD_ID"

# ── Write package.ts ──
cat > package.ts <<EOF
// Auto-generated by upgrade.sh — $(date -u +"%Y-%m-%dT%H:%M:%SZ")
// Network: ${SUI_NETWORK}
// Deployer: ${DEPLOYER_ADDRESS}

export const packages = {
  entity: "${ENTITY_ID}",
  components: "${COMPONENTS_ID}",
  systems: "${SYSTEMS_ID}",
  world: "${WORLD_ID}",
} as const;

export const network = "${SUI_NETWORK}";
export const deployer = "${DEPLOYER_ADDRESS}";
EOF

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ All packages upgraded successfully!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  entity:     $ENTITY_ID"
echo "  components: $COMPONENTS_ID"
echo "  systems:    $SYSTEMS_ID"
echo "  world:      $WORLD_ID"
echo ""
echo "  📄 Package IDs written to package.ts"
echo "  🌐 Network: $SUI_NETWORK"
echo "═══════════════════════════════════════════════════════"
