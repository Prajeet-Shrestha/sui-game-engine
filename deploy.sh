#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# deploy.sh — Deploy all Sui Game Engine packages in order:
#   1. entity  2. components  3. systems  4. world
#
# Reads SUI_NETWORK and MNEMONIC from .env
# Logs each package ID into package.ts as an exported object
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
echo "  Sui Game Engine — Package Deployer"
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

# ── Clean stale build artifacts & publication records ──
echo "🧹 Cleaning build artifacts and publication records..."
PACKAGES=("entity" "components" "systems" "world")
for pkg in "${PACKAGES[@]}"; do
  rm -rf "./${pkg}/build"
  find "./${pkg}" -name "Published.toml" -delete 2>/dev/null || true
done

# Reset Move.toml files to clean state
echo "🔄 Resetting Move.toml files..."
git checkout -- entity/Move.toml components/Move.toml systems/Move.toml world/Move.toml 2>/dev/null || true
echo "   Done."
echo ""

# ── Temp file for publish output ──
TMPJSON=$(mktemp /tmp/sui-publish-XXXXXX.json)
trap "rm -f $TMPJSON" EXIT

# ── Helper: deploy a package and extract its package ID ──
deploy_package() {
  local pkg_name="$1"
  local pkg_dir="$2"

  echo "────────────────────────────────────────────────────"
  echo "📦 Deploying: $pkg_name"
  echo "   Directory: $pkg_dir"
  echo "────────────────────────────────────────────────────"

  # Publish — stdout (JSON) goes to temp file, stderr (warnings) to terminal
  if ! sui client publish "$pkg_dir" \
    --gas-budget 500000000 \
    --skip-dependency-verification \
    --json > "$TMPJSON" 2>&1; then

    # Command failed — check if TMPJSON has valid JSON (sometimes sui
    # writes JSON even when returning non-zero exit code)
    if jq -e '.effects' "$TMPJSON" >/dev/null 2>&1; then
      echo "⚠️  sui client publish returned non-zero but JSON looks valid, continuing..." >&2
    else
      echo "❌ 'sui client publish' command failed for $pkg_name"
      cat "$TMPJSON"
      return 1
    fi
  fi

  # ── Extract status ──
  # Sui CLI may output warnings/notes before the JSON. Strip everything
  # before the first '{' to get clean JSON.
  local clean_json
  clean_json=$(sed -n '/^{/,$ p' "$TMPJSON")

  if [ -z "$clean_json" ]; then
    echo "❌ No JSON found in publish output for $pkg_name"
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
    echo "❌ Deployment failed for $pkg_name (status: $status)"
    echo "$clean_json" | jq '.effects' 2>/dev/null || echo "$clean_json"
    return 1
  fi

  # ── Extract package ID — try multiple JSON formats ──
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
    echo "❌ Could not extract package ID from publish output for $pkg_name"
    echo "$clean_json" | jq '{objectChanges, changed_objects}' 2>/dev/null || echo "$clean_json"
    return 1
  fi

  echo "✅ $pkg_name deployed: $package_id"
  echo ""

  # Return package ID via a global variable (avoid stdout capture issues)
  LAST_PACKAGE_ID="$package_id"
}

# ── Helper: update a package's own Move.toml after publishing ──
mark_published() {
  local pkg_dir="$1"
  local pkg_name="$2"
  local package_id="$3"
  local toml="$pkg_dir/Move.toml"

  # Add published-at field under [package] if not already present
  if ! grep -q "published-at" "$toml"; then
    sed -i '' "/^\[package\]/a\\
published-at = \"${package_id}\"
" "$toml"
  fi

  # Update the package's own address: 0x0 → published ID
  sed -i '' "s|^${pkg_name} = \"0x0\"|${pkg_name} = \"${package_id}\"|" "$toml"
}

# ═══════════════════════════════════════════════════════
#  Deploy in dependency order
# ═══════════════════════════════════════════════════════

# 1. Entity (no dependencies)
deploy_package "entity" "./entity"
ENTITY_ID="$LAST_PACKAGE_ID"
mark_published "./entity" "entity" "$ENTITY_ID"

# 2. Components (depends on entity)
deploy_package "components" "./components"
COMPONENTS_ID="$LAST_PACKAGE_ID"
mark_published "./components" "components" "$COMPONENTS_ID"

# 3. Systems (depends on entity, components)
deploy_package "systems" "./systems"
SYSTEMS_ID="$LAST_PACKAGE_ID"
mark_published "./systems" "systems" "$SYSTEMS_ID"

# 4. World (depends on entity, components, systems)
deploy_package "world" "./world"
WORLD_ID="$LAST_PACKAGE_ID"
mark_published "./world" "world" "$WORLD_ID"

# ── Write package.ts ──
cat > package.ts <<EOF
// Auto-generated by deploy.sh — $(date -u +"%Y-%m-%dT%H:%M:%SZ")
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
echo "  ✅ All packages deployed successfully!"
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
