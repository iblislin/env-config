#!/bin/sh

# https://superuser.com/questions/616642/how-to-use-nat-iptables-rules-for-hostapd

NIC=enp0s31f6
WNIC=wlp0s20f0u2u2
iptables -t nat -A POSTROUTING -o $NIC -j MASQUERADE
iptables -A FORWARD -i $NIC -o $WNIC -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WNIC -o $NIC -j ACCEPT

