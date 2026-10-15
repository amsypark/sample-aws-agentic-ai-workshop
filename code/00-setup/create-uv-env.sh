#!/bin/bash

# UV environment setup and Jupyter kernel registration script (pyproject.toml based)
# Usage: ./create-uv-env.sh <env-name> [python-version]

set -e  # stop the script on any error

# Remember the script directory (used later)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions: output messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print usage
usage() {
    echo "Usage: $0 <env-name> [python-version]"
    echo ""
    echo "Examples:"
    echo "  $0 myenv"
    echo "  $0 myenv 3.12"
    echo ""
    echo "Options:"
    echo "  env-name        : name of the environment to create (required)"
    echo "  python-version  : Python version to use (optional, default: 3.12)"
    echo ""
    echo "pyproject.toml requires Python >=3.12, so use 3.12 or later."
    exit 1
}

# Validate arguments
if [ $# -lt 1 ]; then
    print_error "An environment name is required."
    usage
fi

ENV_NAME=$1
PYTHON_VERSION=${2:-3.12}
VENV_PATH=".venv"  # set the virtual environment path explicitly

print_info "Starting environment setup..."
print_info "Environment name: $ENV_NAME"
print_info "Python version: $PYTHON_VERSION"
print_info "Virtual environment path: $VENV_PATH"

# Clean up any existing virtual environment
if [ -d "$VENV_PATH" ]; then
    print_warning "Removing the existing virtual environment: $VENV_PATH"
    rm -rf .venv
    print_success "The existing virtual environment has been removed."
fi

# Check for UV and install it automatically
install_uv() {
    print_info "Installing UV..."

    # Use the official installer (recommended)
    print_info "Using the official installer script..."
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Update PATH (add the possible install locations)
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    # Source the env file if there is one
    if [ -f "$HOME/.local/bin/env" ]; then
        source "$HOME/.local/bin/env"
    fi

    # Verify the installation
    if command -v uv &> /dev/null; then
        print_success "UV has been installed successfully!"
        uv --version
    else
        print_error "UV installation failed."
        print_info "Manual installation options:"
        echo "  1. Official script: curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo "  2. pip: pip install uv"
        echo "  3. pipx: pipx install uv"
        exit 1
    fi
}

if ! command -v uv &> /dev/null; then
    print_warning "UV is not installed."
    read -p "Install UV automatically? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_uv
    else
        print_error "UV is required. Please install it manually."
        print_info "Installation options:"
        echo "  1. Official script (recommended): curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo "  2. pip: pip install uv"
        echo "  3. pipx: pipx install uv"
        exit 1
    fi
fi

# 1. Set the Python version (before creating the virtual environment)
print_info "Setting Python $PYTHON_VERSION..."
uv python pin $PYTHON_VERSION
print_success "Python $PYTHON_VERSION has been set."

# 2. Initialize the project
print_info "Initializing the project..."
if [ ! -f "pyproject.toml" ]; then
    uv init --name "$ENV_NAME"
    print_success "The project has been initialized as '$ENV_NAME'."
else
    print_warning "pyproject.toml already exists. Using the existing project."
fi

# 3. Add the required packages
print_info "Adding the required Jupyter packages..."
uv add ipykernel jupyter

# 4. Check pyproject.toml and install dependencies
if [ -f "pyproject.toml" ]; then
    print_info "Found pyproject.toml. Syncing dependencies..."

    # Sync the environment from the dependencies in pyproject.toml
    uv sync

    print_success "Dependencies have been installed from pyproject.toml."
    print_info "The lock file was created/updated automatically: uv.lock"
else
    print_error "pyproject.toml is missing. Project initialization may have failed."
    exit 1
fi

print_info "Installing system packages..."

# Install Node.js (needed for npx-based MCP servers such as Playwright MCP; requires 22+)
NODE_MIN_MAJOR=22
node_major() {
    node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'
}

print_info "Checking for Node.js and npm..."
if command -v node &> /dev/null && [ "$(node_major)" -ge "$NODE_MIN_MAJOR" ]; then
    print_success "Node.js is already installed."
    node --version
    npm --version
else
    if command -v node &> /dev/null; then
        print_warning "Node.js $(node -v) is too old for Playwright MCP. Installing Node.js $NODE_MIN_MAJOR."
    else
        print_warning "Node.js is not installed."
    fi

    # macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            print_info "Installing Node.js with Homebrew..."
            brew install node
        else
            print_warning "Homebrew is not installed."
            print_info "Please install Node.js manually: https://nodejs.org/"
        fi
    # Linux
    else
        print_info "Installing Node.js $NODE_MIN_MAJOR via nvm..."
        export NVM_DIR="$HOME/.nvm"
        # nvm scripts can exit non-zero under set -e, so disable it temporarily
        set +e
        if [ ! -s "$NVM_DIR/nvm.sh" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        fi
        . "$NVM_DIR/nvm.sh"
        nvm install "$NODE_MIN_MAJOR"
        nvm alias default "$NODE_MIN_MAJOR"
        nvm use default
        set -e
    fi

    # Verify the installation
    if command -v node &> /dev/null && [ "$(node_major)" -ge "$NODE_MIN_MAJOR" ]; then
        print_success "Node.js has been installed successfully!"
        node --version
        npm --version
        print_info "Open a new terminal or run 'source ~/.bashrc' to use it in your current terminal."
    else
        print_warning "Node.js installation failed. Please install it manually."
        print_info "Installation URL: https://nodejs.org/"
    fi
fi

# Install Chrome for Playwright MCP (Linux only)
# @playwright/mcp uses the 'chrome' channel by default and looks for the browser at /opt/google/chrome/chrome.
CHROME_PATH="/opt/google/chrome/chrome"
install_chrome() {
    local arch
    arch=$(uname -m)
    if [ "$arch" = "x86_64" ]; then
        if command -v dnf &> /dev/null; then
            sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
        elif command -v apt-get &> /dev/null; then
            curl -fsSL -o /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
            sudo apt-get update
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/google-chrome-stable_current_amd64.deb
            rm -f /tmp/google-chrome-stable_current_amd64.deb
        else
            print_warning "Neither dnf nor apt-get was found. Skipping Chrome installation."
            return 1
        fi
    else
        # Google does not publish Chrome for arm64 (Graviton), so use Playwright's Chrome for Testing instead.
        print_info "Detected $arch. Installing Chrome for Testing..."
        if command -v dnf &> /dev/null; then
            sudo dnf install -y nss atk at-spi2-atk at-spi2-core cups-libs libdrm libxkbcommon libXcomposite libXdamage libXfixes libXrandr libXext libXi libX11 mesa-libgbm alsa-lib pango cairo expat
        elif command -v apt-get &> /dev/null; then
            sudo env "PATH=$PATH" npx --yes playwright@latest install-deps chromium
        fi
        npx --yes @playwright/mcp@latest install-browser chrome-for-testing
        local chrome_bin
        chrome_bin=$(find "$HOME/.cache/ms-playwright" -maxdepth 3 -type f -name chrome 2>/dev/null | grep -v headless | head -1)
        if [ -z "$chrome_bin" ]; then
            print_warning "Could not find the Chrome for Testing binary."
            return 1
        fi
        sudo mkdir -p /opt/google/chrome
        sudo ln -sf "$chrome_bin" "$CHROME_PATH"
    fi
}

if [[ "$OSTYPE" != "darwin"* ]]; then
    print_info "Checking for the Chrome browser used by Playwright MCP..."
    if [ -x "$CHROME_PATH" ]; then
        print_success "Chrome is already installed."
    elif install_chrome && [ -x "$CHROME_PATH" ]; then
        print_success "Chrome has been installed successfully!"
    else
        print_warning "Chrome installation failed. The Playwright MCP lab may not work."
    fi
    [ -x "$CHROME_PATH" ] && "$CHROME_PATH" --version || true
fi

# 5. Register the Jupyter kernel
print_info "Registering the Jupyter kernel..."
DISPLAY_NAME="$ENV_NAME (UV)"

# Remove the existing kernel if there is one
if jupyter kernelspec list 2>/dev/null | grep -q "$ENV_NAME"; then
    print_warning "Removing the existing '$ENV_NAME' kernel..."
    jupyter kernelspec remove -f "$ENV_NAME" || {
        print_warning "Kernel removal failed, continuing anyway..."
    }
fi

# Register the new kernel (with error handling)
uv run python -m ipykernel install --user --name "$ENV_NAME" --display-name "$DISPLAY_NAME" || {
    print_error "Jupyter kernel registration failed."
    print_info "To register it manually: uv run python -m ipykernel install --user --name \"$ENV_NAME\" --display-name \"$DISPLAY_NAME\""
    exit 1
}
print_success "The Jupyter kernel has been registered as '$DISPLAY_NAME'."

# 6. Verify the installation
print_info "Verifying the installation..."
echo ""
echo "=== Installed Python version ==="
uv run python --version

echo ""
echo "=== Installed packages ==="
uv pip list

echo ""
echo "=== pyproject.toml dependencies ==="
if command -v grep &> /dev/null && [ -f "pyproject.toml" ]; then
    grep -A 20 "dependencies = \[" pyproject.toml || echo "Could not read the dependency information."
fi

echo ""
echo "=== Registered Jupyter kernels ==="
jupyter kernelspec list 2>/dev/null | grep -E "(Available|$ENV_NAME)" || echo "Could not retrieve the kernel list."

# 7. Link the environment files into the root directory (create symlinks)
print_info "Linking the UV environment files into the root directory..."
cd ..

# Back up and remove any existing files
for file in pyproject.toml .venv uv.lock; do
    if [ -e "$file" ] && [ ! -L "$file" ]; then
        print_warning "Backing up the existing $file as ${file}.backup."
        mv "$file" "${file}.backup"
    elif [ -L "$file" ]; then
        print_info "Removing the existing symlink $file."
        rm -f "$file"
    fi
done

# Create the symlinks (using absolute paths)
SOURCE_DIR="$SCRIPT_DIR"

ln -sf "$SOURCE_DIR/pyproject.toml" . || {
    print_error "Failed to create the pyproject.toml symlink"
    print_error "Current directory: $(pwd)"
    print_error "Source path: $SOURCE_DIR/pyproject.toml"
    exit 1
}

ln -sf "$SOURCE_DIR/.venv" . || {
    print_error "Failed to create the .venv symlink"
    print_error "Current directory: $(pwd)"
    print_error "Source path: $SOURCE_DIR/.venv"
    exit 1
}

if [ -f "$SOURCE_DIR/uv.lock" ]; then
    ln -sf "$SOURCE_DIR/uv.lock" . || {
        print_warning "Failed to create the uv.lock symlink"
    }
fi

print_success "The UV environment files have been linked into the root directory!"

echo ""
print_success "Environment setup is complete!"
echo ""
echo "=== How to use it ==="
echo "1. Add a package: uv add <package-name>"
echo "2. Remove a package: uv remove <package-name>"
echo "3. Sync dependencies: uv sync"
echo "4. Run a script: uv run python main.py (works from the root!)"
echo "5. Start Jupyter Lab: uv run jupyter lab"
echo "6. When creating a new notebook, select the '$DISPLAY_NAME' kernel"
echo ""
echo "=== File information ==="
echo "- pyproject.toml: project settings and dependencies (managed in 00-setup/, symlinked at the root)"
echo "- uv.lock: exact version lock file (recommended to keep in version control)"
echo "- .venv/: virtual environment directory (excluded from version control)"
echo ""
print_info "You can now run 'uv run python main.py' from the root directory!"
print_info "Activate it the traditional way: source .venv/bin/activate"
print_info "The UV-recommended way: uv run <command>"
