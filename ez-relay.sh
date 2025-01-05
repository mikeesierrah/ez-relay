#!/bin/bash

# Install Sing-Box using the provided script
echo "Installing Sing-Box..."
bash <(curl -fsSL https://sing-box.app/deb-install.sh)

systemctl disable sing-box
systemctl stop sing-box

# Create directory for relay configuration
RELAY_CONFIG_DIR="/etc/relay"
mkdir -p "$RELAY_CONFIG_DIR"
CONFIG_PATH="$RELAY_CONFIG_DIR/config.json"

# Prompt for configuration inputs
read -p "Enter listen port: " LISTEN_PORT
read -p "Enter destination port: " DESTINATION_PORT
read -p "Enter destination address: " DESTINATION_ADDRESS

# Define the custom configuration using user inputs
CONFIG_CONTENT="{
    \"inbounds\": [
        {
            \"type\": \"direct\",
            \"tag\": \"direct-in\",
            \"listen\": \"::\",
            \"tcp_fast_open\": \"true\",
            \"listen_port\": $LISTEN_PORT,
            \"override_address\": \"$DESTINATION_ADDRESS\",
            \"override_port\": $DESTINATION_PORT
        }
    ]
}"

# Write the configuration to /etc/relay/config.json
echo "Writing configuration to $CONFIG_PATH..."
echo "$CONFIG_CONTENT" > "$CONFIG_PATH"

if [ $? -ne 0 ]; then
    echo "Error: Failed to write configuration file. Are you running as root?"
    exit 1
fi

# Install the relay script
echo "Installing relay script in /usr/local/bin..."
cat <<'EOF' > /usr/local/bin/relay
#!/bin/bash

# Check for the correct number of arguments
if [[ "$#" -ne 3 ]]; then
    echo "Usage: relay <port> <target-port> <ip>"
    exit 1
fi

port=$1
target=$2
IP=$3
CONFIG_PATH="/etc/relay/config.json"

# Create the inbound rule JSON block
inbound_rule=$(cat <<EOM
{
  "type": "direct",
  "tag": "tunnel-$port",
  "listen": "::",
  "tcp_fast_open": true,
  "listen_port": $port,
  "override_address": "$IP",
  "override_port": $target
}
EOM
)

# Check if the inbound rule for the specified port already exists
existing_rule=$(jq --arg port "$port" '.inbounds[] | select(.listen_port == ($port | tonumber))' "$CONFIG_PATH")

if [[ -n "$existing_rule" ]]; then
    # Update the existing rule
    tmp=$(mktemp)
    jq --argjson inbound "$inbound_rule" --arg port "$port" '
        (.inbounds[] | select(.listen_port == ($port | tonumber))) = $inbound
    ' "$CONFIG_PATH" > "$tmp" && mv "$tmp" "$CONFIG_PATH"
    echo "Updated inbound rule for port $port in config.json."
else
    # Add a new rule
    tmp=$(mktemp)
    jq --argjson inbound "$inbound_rule" '.inbounds += [$inbound]' "$CONFIG_PATH" > "$tmp" && mv "$tmp" "$CONFIG_PATH"
    echo "Added inbound rule to config.json."
fi


systemctl restart relay
EOF

# Make the relay script executable
chmod +x /usr/local/bin/relay

# Create the relay systemd service
echo "Creating relay systemd service..."
cat <<EOF > /etc/systemd/system/relay.service
[Unit]
Description=Relay Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target network-online.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C $RELAY_CONFIG_DIR run
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon and enable the relay service
echo "Enabling and starting relay service..."
systemctl daemon-reload
systemctl enable relay
systemctl start relay

echo "Relay service installed and running!"
