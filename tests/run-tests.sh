#!/usr/bin/env zsh

set -e

# Check if the script argument is provided
if [ -z "$1" ]; then
    echo "❌  You must provide the path to the installation script."
    echo "Usage: ./run-tests.sh /path/to/install.sh"
    exit 1
fi

INSTALL_SCRIPT="$1"

# Check if the install script exists and is executable
if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "❌  The install script '$INSTALL_SCRIPT' does not exist. Please provide a valid path."
    exit 1
fi

echo "🔧 Using installation script: $INSTALL_SCRIPT"

# Execute the installation script
if sh "$INSTALL_SCRIPT"; then
    echo "✅  Installation script executed successfully."
else
    echo "❌  An error occurred while executing the installation script."
    exit 1
fi

# Here you can add commands to run your tests
echo "🔍 Running tests after the installation script..."
# Example:
# dotnet test
