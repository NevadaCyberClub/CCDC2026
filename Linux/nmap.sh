#! /bin/sh
#
# nmap.sh
#


internal_network_range=$1

# if no argument is provided, get range from ip -4 -o addr show
if [ -z "$internal_network_range" ]; then
    internal_network_range=$(ip -4 -o addr show dev eth0 |
        grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' |
        head -n 1)
fi

echo "nmap -p- -T4 -A -v $internal_network_range > ~/nmap-scan.txt"
nmap -p- -T4 -A -v $internal_network_range > ~/nmap-scan.txt
