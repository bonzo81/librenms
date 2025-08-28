#!/bin/bash
# Build-time permission initialization for LibreNMS dev container

set -e

echo "🔧 Initializing build-time permissions..."

# Create librenms-dev group for development
groupadd -f librenms-dev

# Add librenms user to development group
usermod -a -G librenms-dev librenms

# Set basic ownership for LibreNMS directory
chown -R librenms:librenms /opt/librenms

# Set umask for group-writable files by default
echo "umask 002" >> /opt/librenms/.bashrc 2>/dev/null || true

echo "✅ Build-time permission initialization complete"
