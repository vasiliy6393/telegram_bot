#!/bin/sh

GREP="$(which grep)";
AWK="$(which awk)";
IFCONFIG="$(which ifconfig)";
IFACE="ppp0"; n=0; s=0; p=0;

for i in {1..2}; do
    p="$s";
    s="$($IFCONFIG $IFACE | $GREP -P 'RX.*bytes' | $AWK '{print $5}')";
    if [[ "a$p" != "a0" ]]; then
        sp=$(($s-$p));
        if [[ "$sp" -lt "1048576" ]]; then
            speed=$((($sp*8)/1024));
            fract=$((($sp*8)%1024));
            prefix="K";
        else
            speed=$((($sp*8/1024)/1024));
            fract=$((($sp*8/1024)%1024));
            prefix="M";
        fi
        echo "$speed.$fract ${prefix}bps"; break;
    fi
    sleep 1;
done

