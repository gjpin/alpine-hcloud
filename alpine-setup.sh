#!/bin/sh

# Enable openssh server
rc-update add sshd default

# Configure networking
tee /etc/network/interfaces << EOF
iface lo inet loopback
iface eth0 inet dhcp
EOF

ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

rc-update add net.eth0 default
rc-update add net.lo boot

# Configure Cloudflare DNS servers
tee /etc/resolv.conf << EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# Avoid overwriting resolv.conf by DHCP
mkdir -p /etc/udhcpc
tee /etc/udhcpc/udhcpc.conf << EOF
RESOLV_CONF="NO"
EOF

# Create root ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Grab config from metadata service
tee /bin/metadata-init << EOF
#!/bin/sh

# Expand the size of the mounted filesystem
resize2fs /dev/sda

# Get hostname from metadata
curl -s http://169.254.169.254/hetzner/v1/metadata/hostname -o /etc/hostname
hostname -F /etc/hostname

# Get authorized SSH keys from metadata
curl -s http://169.254.169.254/hetzner/v1/metadata/public-keys | jq -r .[] > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# This script only needs to be run once, so remove the service
rc-update del metadata-init default
exit 0
EOF

# Create metadata-init OpenRC service
tee /etc/init.d/metadata-init << EOF
#!/sbin/openrc-run

depend() {
    need net.eth0
}

command="/bin/metadata-init"
command_args=""
pidfile="/tmp/metadata-init.pid"

command_background="yes"
output_log="/var/log/metadata-init.log"
error_log="/var/log/metadata-init.err"
EOF

# Make metadata-init and service executable
chmod +x /etc/init.d/metadata-init
chmod +x /bin/metadata-init

# Enable metadata-init service
rc-update add metadata-init default

# Setup SSHD
tee /etc/ssh/sshd_config << EOF
Port 50004
PermitRootLogin yes
PubkeyAuthentication yes
AuthorizedKeysFile      .ssh/authorized_keys
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS
Subsystem sftp /usr/lib/ssh/sftp-server
AuthenticationMethods publickey
ClientAliveInterval 5m
ClientAliveCountMax 2
EOF