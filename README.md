# ez-relay

A quick and easy relay setup using the Sing-Box core.

## Installation

**Run the script as root:**

Execute the following command to install:

```bash
bash <(curl -Ls https://github.com/mikeesierrah/ez-relay/raw/master/ez-relay.sh)
```

This will install the necessary tools and configure your system for relay functionality.

## Usage

Once the installation is complete, you can use the relay command to set up your relay tunnel. The format is:

```bash
relay <listen-port> <dest-port> <dest-address>
```

### Example

```bash
relay 8080 443 192.168.1.1
```

This command will set up a relay listening on port `8080`, forwarding traffic to port `443` on `192.168.1.1`.

## Credits

- **Sing-Box** (https://sing-box.sagernet.org)

