#!/usr/bin/env bash
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/nftables/nft.sh)
# Wiki: debian buster nftables https://wiki.archlinux.org/index.php/Nftables

# dependencies
command -v nft > /dev/null 2>&1 || { echo >&2 "Please install nftables： apt update && apt install nftables -y"; exit 1; }

# nftables
cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet my_table {
    chain my_input {
        type filter hook input priority 0; policy drop;
        
        ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 1/second accept
        ip6 nexthdr icmpv6 icmpv6 type echo-request counter drop
        
        ip protocol icmp icmp type echo-request limit rate 1/second accept
        ip protocol icmp icmp type echo-request counter drop
        
        ct state {established, related} counter accept
        ct state invalid drop
        
        ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, echo-reply, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
        ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept
        
        iif lo accept

        tcp dport { http, https } counter accept
        udp dport { http, https } counter accept
        tcp dport $(cat /etc/ssh/sshd_config | grep -oE "^Port [0-9]*$" | grep -oE "[0-9]*" || echo 22) ct state new limit rate 5/minute counter accept
        
        counter comment "count dropped packets"
    }
    
    chain my_forward {
        type filter hook forward priority 0; policy accept;
        counter comment "count accepted packets"
    }
    
    chain my_output {
        type filter hook output priority 0; policy accept;
        counter comment "count accepted packets"
    }
}
EOF

systemctl enable nftables && systemctl restart nftables && systemctl status nftables
