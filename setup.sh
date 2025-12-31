#!/bin/bash

echo "🔥 Installing Firebase Cloud Shell VPS..."

# Create directory
mkdir -p ~/.firebase-vps-install
cd ~/.firebase-vps-install

# Download the VPS creator
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/firebase-vps/main/firebase-vps-creator.js

# Make it executable
chmod +x firebase-vps-creator.js

# Create symlink for easy access
sudo ln -sf "$(pwd)/firebase-vps-creator.js" /usr/local/bin/vps

# Install screen if not present
sudo apt-get update
sudo apt-get install -y screen

echo ""
echo "✅ Installation complete!"
echo ""
echo "Usage:"
echo "  vps create    - Create a new VPS"
echo "  vps list      - List all VPS"
echo "  vps status    - Show VPS status"
echo "  vps login     - Login to VPS terminal"
echo "  vps stop      - Stop VPS"
echo "  vps help      - Show help"
echo ""
echo "🔥 Your VPS will run 24/7 in Firebase Cloud Shell!"
