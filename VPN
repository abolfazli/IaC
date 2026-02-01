#!/bin/bash

# Exit if any command fails
set -e

# 1. Update system & install essentials
echo "Updating system and installing necessary packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget unzip ufw uuid-runtime

# 2. Configure firewall (allow port 443)
echo "Configuring firewall to allow port 443..."
sudo ufw allow ssh
sudo ufw allow 443/tcp
sudo ufw enable

# 3. Install XRay
echo "Installing XRay..."
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

# 4. Create config directory
echo "Creating XRay configuration directory..."
sudo mkdir -p /usr/local/etc/xray

# 5. Generate REALITY keys
echo "Generating REALITY keys..."
REACT_PRIVATE_KEY=$(xray x25519 | grep "PrivateKey" | awk '{print $2}')
REACT_PUBLIC_KEY=$(xray x25519 | grep "Password" | awk '{print $2}')
SHORT_ID="6f2a9c1d"  # Modify this to your desired shortId
echo "Generated PrivateKey: $REACT_PRIVATE_KEY"
echo "Generated Public Key: $REACT_PUBLIC_KEY"

# 6. Prompt for usernames (comma separated)
echo "Enter the usernames (comma-separated):"
read -p "Usernames: " USERNAMES

# Split usernames into an array
IFS=',' read -r -a USERNAME_ARRAY <<< "$USERNAMES"

# 7. Generate UUIDs for each user and create config entries
echo "Generating UUIDs and configuring clients..."
UUIDS=()
for USERNAME in "${USERNAME_ARRAY[@]}"; do
    UUID=$(uuidgen)
    UUIDS+=("$UUID")
    echo "Generated UUID for $USERNAME: $UUID"
done

# 8. Create config.json for XRay
echo "Creating XRay config.json..."
sudo bash -c "cat > /usr/local/etc/xray/config.json <<EOF
{
  \"log\": {
    \"loglevel\": \"warning\"
  },
  \"inbounds\": [
    {
      \"port\": 443,
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [
EOF"

# Add clients to config
for i in "${!USERNAME_ARRAY[@]}"; do
    USERNAME="${USERNAME_ARRAY[$i]}"
    UUID="${UUIDS[$i]}"
    sudo bash -c "cat >> /usr/local/etc/xray/config.json <<EOF
          { \"id\": \"$UUID\", \"email\": \"$USERNAME\" },
EOF"
done

# Finalize config file
sudo bash -c "cat >> /usr/local/etc/xray/config.json <<EOF
        ],
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"tcp\",
        \"security\": \"reality\",
        \"realitySettings\": {
          \"show\": false,
          \"dest\": \"art.fidibo.com:443\",
          \"xver\": 0,
          \"serverNames\": [\"art.fidibo.com\"],
          \"privateKey\": \"$REACT_PRIVATE_KEY\",
          \"shortIds\": [\"$SHORT_ID\"]
        }
      }
    }
  ],
  \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {}
    }
  ]
}
EOF"

# 9. Enable & restart XRay
echo "Enabling and restarting XRay service..."
sudo systemctl enable xray
sudo systemctl restart xray

# 10. Check status
echo "Checking XRay status..."
sudo systemctl status xray

# 11. Watch logs while testing
echo "You can monitor XRay logs using 'sudo journalctl -u xray -f' when clients connect."

# 12. Finished setup
echo "XRay REALITY server setup complete!"

# 13. Provide client URI examples
echo "Client REALITY URI examples:"
for i in "${!USERNAME_ARRAY[@]}"; do
    USERNAME="${USERNAME_ARRAY[$i]}"
    UUID="${UUIDS[$i]}"
    echo "vless://$UUID@your.server.com:443?encryption=none&security=reality&pbk=$REACT_PUBLIC_KEY&sid=$SHORT_ID&spx=%2F&fp=chrome&type=tcp&sni=art.fidibo.com#$USERNAME-REALITY"
done
