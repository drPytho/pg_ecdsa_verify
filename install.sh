#!/bin/bash
set -e

# pg_ecdsa_verify installer
# Usage: ./install.sh --pg17 or ./install.sh --pg18

REPO="joelonsql/pg_ecdsa_verify"
EXTENSION_NAME="pg_ecdsa_verify"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [--pg17|--pg18] [--version VERSION] [--pkglibdir DIR] [--sharedir DIR]"
    echo ""
    echo "Options:"
    echo "  --pg17           Install for PostgreSQL 17"
    echo "  --pg18           Install for PostgreSQL 18"
    echo "  --version VER    Install specific version (e.g., v1.2.4). Default: latest"
    echo "  --pkglibdir DIR  Custom directory for .so files (default: pg_config --pkglibdir)"
    echo "  --sharedir DIR   Custom directory for .control/.sql files (default: pg_config --sharedir/extension)"
    echo "  --help           Show this help message"
    exit 1
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}==>${NC} $1"
}

warn() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

# Parse arguments
PG_VERSION=""
VERSION="latest"
CUSTOM_PKGLIBDIR=""
CUSTOM_SHAREDIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --pg17)
            PG_VERSION="17"
            shift
            ;;
        --pg18)
            PG_VERSION="18"
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --pkglibdir)
            CUSTOM_PKGLIBDIR="$2"
            shift 2
            ;;
        --sharedir)
            CUSTOM_SHAREDIR="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validate PostgreSQL version
if [[ -z "$PG_VERSION" ]]; then
    error "PostgreSQL version required. Use --pg17 or --pg18"
fi

# Check for required tools
for cmd in curl tar; do
    if ! command -v "$cmd" &> /dev/null; then
        error "$cmd is required but not installed"
    fi
done

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        ;;
esac

# Find pg_config
if command -v pg_config &> /dev/null; then
    PG_CONFIG="pg_config"
elif [[ -x "/usr/lib/postgresql/${PG_VERSION}/bin/pg_config" ]]; then
    PG_CONFIG="/usr/lib/postgresql/${PG_VERSION}/bin/pg_config"
elif [[ -x "/usr/pgsql-${PG_VERSION}/bin/pg_config" ]]; then
    PG_CONFIG="/usr/pgsql-${PG_VERSION}/bin/pg_config"
else
    error "pg_config not found. Is PostgreSQL ${PG_VERSION} installed?"
fi

# Verify PostgreSQL version matches
INSTALLED_PG_VERSION=$("$PG_CONFIG" --version | grep -oP '\d+' | head -1)
if [[ "$INSTALLED_PG_VERSION" != "$PG_VERSION" ]]; then
    warn "pg_config reports PostgreSQL $INSTALLED_PG_VERSION but you requested $PG_VERSION"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get installation directories (use custom paths if provided)
if [[ -n "$CUSTOM_PKGLIBDIR" ]]; then
    PKGLIBDIR="$CUSTOM_PKGLIBDIR"
else
    PKGLIBDIR=$("$PG_CONFIG" --pkglibdir)
fi

if [[ -n "$CUSTOM_SHAREDIR" ]]; then
    SHAREDIR="$CUSTOM_SHAREDIR"
else
    SHAREDIR=$("$PG_CONFIG" --sharedir)/extension
fi

# Create directories if they don't exist
if [[ ! -d "$PKGLIBDIR" ]]; then
    warn "Directory $PKGLIBDIR does not exist, will create it"
fi
if [[ ! -d "$SHAREDIR" ]]; then
    warn "Directory $SHAREDIR does not exist, will create it"
fi

info "PostgreSQL version: $PG_VERSION"
info "Library directory: $PKGLIBDIR"
info "Extension directory: $SHAREDIR"

# Fetch latest version if needed
if [[ "$VERSION" == "latest" ]]; then
    info "Fetching latest release..."
    VERSION=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$VERSION" ]]; then
        error "Failed to fetch latest version"
    fi
fi

info "Installing version: $VERSION"

# Construct download URL
# Remove 'v' prefix for the filename if present
VERSION_NUM="${VERSION#v}"
TARBALL="${EXTENSION_NAME}-${VERSION_NUM}-pg${PG_VERSION}-linux-${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${TARBALL}"

# Create temp directory
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

info "Downloading ${TARBALL}..."
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TMPDIR/$TARBALL"; then
    error "Failed to download from $DOWNLOAD_URL"
fi

info "Extracting..."
tar -xzf "$TMPDIR/$TARBALL" -C "$TMPDIR"

# Find and install files
info "Installing extension files..."

# Check if we need sudo
NEED_SUDO=""
if [[ ! -w "$PKGLIBDIR" ]] || [[ ! -w "$SHAREDIR" ]]; then
    NEED_SUDO="sudo"
    warn "Root privileges required for installation"
fi

# Create directories if needed
$NEED_SUDO mkdir -p "$PKGLIBDIR"
$NEED_SUDO mkdir -p "$SHAREDIR"

# Install .so file from lib/
if [ -d "$TMPDIR/lib" ]; then
    $NEED_SUDO cp -v "$TMPDIR"/lib/*.so "$PKGLIBDIR/"
else
    find "$TMPDIR" -name "*.so" -exec $NEED_SUDO cp -v {} "$PKGLIBDIR/" \;
fi

# Install control and SQL files from extension/
if [ -d "$TMPDIR/extension" ]; then
    $NEED_SUDO cp -v "$TMPDIR"/extension/*.control "$SHAREDIR/"
    $NEED_SUDO cp -v "$TMPDIR"/extension/*.sql "$SHAREDIR/"
else
    find "$TMPDIR" -name "*.control" -exec $NEED_SUDO cp -v {} "$SHAREDIR/" \;
    find "$TMPDIR" -name "*.sql" -exec $NEED_SUDO cp -v {} "$SHAREDIR/" \;
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "To enable the extension in your database, run:"
echo "  CREATE EXTENSION pg_ecdsa_verify;"
