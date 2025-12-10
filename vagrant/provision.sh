#!/usr/bin/env bash
# vagrant/provision.sh - idempotent provisioning for asm3 dev/test environment

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

PROJECT_DIR="/vagrant"
VENV_DIR="$PROJECT_DIR/.venv"

echo "Provision: updating apt and installing system packages..."
apt-get update -y
apt-get install -y --no-install-recommends \
    build-essential \
    python3 \
    python3-venv \
    python3-pip \
    python3-pil \
    python3-cheroot \
    python3-mysqldb \
    python3-psycopg2 \
    python3-memcache \
    sqlite3 \
    git \
    libjpeg-dev \
    zlib1g-dev \
    locales \
    wget \
    curl \
    gpg \
    ca-certificates

echo "Installing desktop environment..."
apt-get install -y ubuntu-desktop-minimal

# Install VS Code
echo "Installing VS Code..."
if ! command -v code &> /dev/null; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
  apt-get update -y
  apt-get install -y code
fi

# Install Zed
echo "Installing Zed editor..."
if ! command -v zed &> /dev/null; then
  curl -f https://zed.dev/install.sh | sh
  # Make zed available system-wide (the install script installs to ~/.local for the running user)
  # For vagrant user, we'll install it in their home directory
  sudo -u vagrant -H bash -c "curl -f https://zed.dev/install.sh | sh"
fi

# Ensure a sane locale (avoid python warnings)
locale-gen en_US.UTF-8 || true
update-locale LANG=en_US.UTF-8 || true
export LANG=en_US.UTF-8

# Create venv as the vagrant user (idempotent)
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtualenv in $VENV_DIR ..."
  sudo -u vagrant -H python3 -m venv --system-site-packages "$VENV_DIR"
fi

echo "Upgrading pip and installing Python packages..."
sudo -u vagrant -H "$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel

if [ -f "$PROJECT_DIR/requirements.txt" ]; then
  echo "Installing from requirements.txt..."
  sudo -u vagrant -H "$VENV_DIR/bin/pip" install -r "$PROJECT_DIR/requirements.txt"
else
  echo "No requirements.txt found; installing a minimal test toolchain..."
  sudo -u vagrant -H "$VENV_DIR/bin/pip" install coverage
fi

# Generate __version__.py (required by asm3 imports)
echo "Generating version file..."
if [ -f "$PROJECT_DIR/VERSION" ]; then
  cat > "$PROJECT_DIR/src/asm3/__version__.py" <<EOF
#!/usr/bin/env python3
VERSION = "$(cat $PROJECT_DIR/VERSION) [$(date)]"
BUILD = "$(date +%m%d%H%M%S)"
EOF
  chown vagrant:vagrant "$PROJECT_DIR/src/asm3/__version__.py" || true
fi

# Initialize test DB (idempotent)
if [ -f "$PROJECT_DIR/scripts/unittestdb/make_db.py" ]; then
  echo "Initializing base test DB..."
  # run as the vagrant user in case scripts expect permissions/paths
  sudo -u vagrant -H bash -lc "cd '$PROJECT_DIR' && python3 scripts/unittestdb/make_db.py || true"
  # copy base.db → test.db if not present
  if [ -f "$PROJECT_DIR/scripts/unittestdb/base.db" ] && [ ! -f "$PROJECT_DIR/scripts/unittestdb/test.db" ]; then
    cp "$PROJECT_DIR/scripts/unittestdb/base.db" "$PROJECT_DIR/scripts/unittestdb/test.db"
    chown vagrant:vagrant "$PROJECT_DIR/scripts/unittestdb/test.db" || true
  fi
fi

# Helpful reminder for the user
cat > "$PROJECT_DIR/VAGRANT_SETUP_COMPLETE" <<'EOF'
Vagrant provisioning complete.

To use the environment:
  vagrant ssh
  cd /vagrant
  source .venv/bin/activate

Run tests:
  # Run the bundle entrypoint:
  python3 unittest/suite.py

  # Or use discovery (same as VS Code settings.json)
  python3 -m unittest discover -s unittest -p "test_*.py"

Run coverage:
  coverage run --source=src -m unittest discover -s unittest -p "test_*.py"
  coverage report -m
  coverage html   # results in htmlcov/index.html

Notes:
- The virtualenv is at .venv (project root).
- The test DB lives at scripts/unittestdb/test.db (created from base.db during provisioning).
EOF

echo "Provisioning finished. See /vagrant/VAGRANT_SETUP_COMPLETE for next steps."