#!/bin/sh
GREP="$(which grep)";
AWK="$(which awk)";
IFCONFIG="$(which ifconfig)";
IFACE="your_interface"; s=0; p=0; 

for i in {1..2}; do
    p="$s";
    s="$($IFCONFIG $IFACE | $GREP -P 'RX.*bytes' | $AWK '{print $5}')";
    if [[ "a$p" != "a0" ]]; then
        sp="$((($s-$p)*8))";
        if [[ "$sp" -lt "1024" ]]; then
            speed="$(($sp))";
            fract="00";
            pref="";
        elif [[ "$sp" -lt "1048576" ]]; then
            speed="$((($sp)/1024))";
            fract="$((($sp)%1024))";
            pref="K";
        else
            speed="$((($sp/1024)/1024))";
            fract="$((($sp/1024)%1024))";
            pref="M";
        fi
        echo "$speed.$fract ${pref}bps"; break;
    fi
    sleep 1;
done
