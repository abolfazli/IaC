#!/bin/bash

# Prompt for the public IP of the server
read -p "Enter the public IP of the server: " PUBLIC_IP

# Update system and install necessary packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget unzip ufw

# Configure UFW firewall
sudo ufw allow ssh
sudo ufw allow 443/tcp
sudo ufw enable

# Install Xray
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

# Create the configuration directory
sudo mkdir -p /usr/local/etc/xray

# Generate x25519 keys for Reality protocol
KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "PrivateKey" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Password" | awk '{print $2}')
SHORT_ID=$(echo "$PRIVATE_KEY" | cut -c 1-8)
UUID=$(uuidgen)

# Create the Xray configuration file
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
          { \"id\": \"$UUID\", \"email\": \"amir\" }
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
          \"privateKey\": \"$PRIVATE_KEY\",
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

# Enable and restart Xray service
sudo systemctl enable xray
sudo systemctl restart xray
sudo systemctl status xray

# Output client config
echo "Final Client Config: "
echo "vless://$UUID@$PUBLIC_IP:443?encryption=none&security=reality&pbk=$PUBLIC_KEY&sid=$SHORT_ID&spx=%2F&fp=chrome&type=tcp&sni=art.fidibo.com#Reality-Amir"
