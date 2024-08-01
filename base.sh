#!/bin/bash
set -ex

# Get version from args or set default
VER=$1
COCKROACHDB_VERSION=${VER-24.1.2}

# Setup NTP
timedatectl set-ntp no
apt-get update && apt-get install ntp -y
service ntp stop
sed -i "s/^pool/# pool/g" /etc/ntp.conf
cat<<EOF>>/etc/ntp.conf
server time1.google.com iburst
server time2.google.com iburst
server time3.google.com iburst
server time4.google.com iburst
EOF
service ntp start

# Install CockroachDB
curl https://binaries.cockroachdb.com/cockroach-v${COCKROACHDB_VERSION}.linux-amd64.tgz | tar -xz
cp -i cockroach-v${COCKROACHDB_VERSION}.linux-amd64/cockroach /usr/local/bin/
mkdir -p /usr/local/lib/cockroach
cp -i cockroach-v${COCKROACHDB_VERSION}.linux-amd64/lib/libgeos.so /usr/local/lib/cockroach/
cp -i cockroach-v${COCKROACHDB_VERSION}.linux-amd64/lib/libgeos_c.so /usr/local/lib/cockroach/
rm -rf cockroach-v${COCKROACHDB_VERSION}.linux-amd64

# Build Service pre-requisite
mkdir -p /var/lib/cockroach/{ca,certs}
useradd -d /var/lib/cockroach cockroach
chown -R cockroach:cockroach /var/lib/cockroach
cat<<EOF>/etc/systemd/system/cockroachdb.service
[Unit]
Description=Cockroach Database cluster node
Requires=network.target
[Service]
Type=notify
WorkingDirectory=/var/lib/cockroach
TimeoutStopSec=300
Restart=always
RestartSec=10
User=cockroach
[Install]
WantedBy=default.target
EOF

# Check data dir exists and give permissions
[ -d "/mnt/data" ] && chown -R cockroach:cockroach /mnt/data || exit 1

# Add helpers
apt-get update && apt-get install zip unzip -y
