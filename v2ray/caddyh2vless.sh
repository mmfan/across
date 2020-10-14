#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:  debian 9/10 one_key for caddy2 v2ray
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/v2ray/caddyh2vless.sh) my.domain.com
# uninstall: apt purge caddy -y; bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; systemctl disable v2ray; rm -rf /usr/local/etc/v2ray /var/log/v2ray

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT
TMPFILE=$(mktemp) || exit 1

########
[[ $# != 1 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com && exit 1 || domain="$1"
v2my_port=$(shuf -i 10000-65535 -n1)
v2my_uuid=$(cat /proc/sys/kernel/random/uuid)
v2my_path=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)
########

# install caddy
caddyURL="$(wget -qO-  https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_amd64\.deb" | cut -f4 -d\" | head -n1)"
wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE

# install v2ray
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# config caddy
cat <<EOF >/etc/caddy/Caddyfile
$domain

root * /usr/share/caddy

file_server

header {
Strict-Transport-Security max-age=31536000;
X-Content-Type-Options nosniff
X-Frame-Options DENY
Referrer-Policy no-referrer-when-downgrade
}

reverse_proxy /$v2my_path localhost:$v2my_port {
transport http {
versions h2c
}
}
EOF

# config v2ray
cat <<EOF >/usr/local/etc/v2ray/config.json
{
    "inbounds": 
    [
        {
            "port": $v2my_port,"listen":"127.0.0.1","protocol": "vless",
            "settings": {"clients": [{"id": "$v2my_uuid"}],"decryption": "none"},
            "streamSettings": {"network": "h2","httpSettings": {"path": "/$v2my_path","host": ["$domain"]}}
        }
    ],
	
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}}
    ],
	
    "routing": 
    {
        "rules": 
        [
            {"type": "field","outboundTag": "blocked","ip": ["geoip:private","geoip:cn"]},
            {"type": "field","outboundTag": "blocked","domain": ["geosite:private","geosite:cn","geosite:category-ads-all"]}
        ]
    }
}
EOF

# systemctl service info
systemctl daemon-reload
echo; echo $(date) caddy status:
systemctl enable caddy && systemctl restart caddy && sleep 1 && systemctl status caddy | more | grep -A 2 "caddy.service"
echo; echo $(date) v2ray status:
systemctl enable v2ray && systemctl restart v2ray && sleep 1 && systemctl status v2ray | more | grep -A 2 "v2ray.service"

# info
echo; echo $(date) v2ray config info:
cat <<EOF >$TMPFILE
        {
            "protocol": "vless",
            "tag": "v2my_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$v2my_uuid","encryption": "none"}]}]},
            "streamSettings": {"network": "h2","security": "tls","tlsSettings": {"allowInsecure": false,"serverName": "$domain"},"httpSettings": {"host": ["$domain"],"path": "/$v2my_path"}}
        },

EOF

cat $TMPFILE
# done
