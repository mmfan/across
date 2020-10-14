#!/bin/bash
# Usage:
#   curl https://raw.githubusercontent.com/mixool/across/master/ssh/securityssh.sh | bash

[[ "$(id -u)" != "0" ]] && echo "ERROR: Please run as root" && exit 1

# Backup
bakname=$(date +%N)
cp /etc/ssh/sshd_config /etc/ssh/sshd_config_$bakname

# custom port
echo "Securing your SSH server with custom port..."
SSH_PORT=${SSH_PORT:-n}
while ! [[ ${SSH_PORT} =~ ^[0-9]+$ ]]; do
    read -p "Custom ssh port: " SSH_PORT </dev/tty
done

if grep -qwE "^Port\ [0-9]*" /etc/ssh/sshd_config; then
    sed -i "s/^Port\ [0-9]*/Port\ ${SSH_PORT}/g" /etc/ssh/sshd_config
else
    sed -i "/^#Port\ [0-9]*/a Port\ ${SSH_PORT}" /etc/ssh/sshd_config
fi


# custom rsa_pub_key login
echo "Securing your SSH server with authorized_keys..."
RSA_PUB_KEY=${RSA_PUB_KEY:-n}
while ! [[ ${RSA_PUB_KEY} =~ ssh-rsa* ]]; do
    read -p "Custom public key: " RSA_PUB_KEY </dev/tty
done

[[ ! -d "/root/.ssh" ]] && mkdir -p "/root/.ssh" && chmod 700 /root/.ssh
echo $RSA_PUB_KEY >> /root/.ssh/authorized_keys
sed -i "s/PermitRootLogin.*/PermitRootLogin without-password/g" /etc/ssh/sshd_config

# Active
service ssh restart

# Info	
echo "ssh port updated to ${SSH_PORT}, please login with authorized_keys"
echo "if login failed, backup file: /etc/ssh/sshd_config_$bakname"
