#!/bin/bash

# if variable is not empty, then include it.
# Hostname is required, if environment variable is not set, use pod name.
if ! [ -z "$fqdn" ]; then
    hostname="-hostname $fqdn"
    else hostname="-hostname $(hostname -f)"
fi

if ! [ -z "$certFile" ]; then
    certFile="-certFile $certFile"
fi

if ! [ -z "$db" ]; then
    db="-db $db"
fi

if ! [ -z "$debug" ]; then
    db="-debug"
fi

if ! [ -z "$https" ]; then
    https="-https"
fi

if ! [ -z "$keyFile" ]; then
    keyFile="-keyFile $keyFile"
fi

if ! [ -z "$listenip" ]; then
    listenip="-listenip $listenip"
fi

if ! [ -z "$listenport" ]; then
    listenport="-listenport $listenport"
fi

if ! [ -z "$reverseProxy" ]; then
    reverseProxy="-reverseProxy"
fi

if ! [ -z "$reverseProxyPort" ]; then
    reverseProxyPort="-reverseProxyPort $reverseProxyPort"
fi

if ! [ -z "$setEdition" ]; then
    db="-setEdition $setEdition"
fi

if ! [ -z "$setPass" ]; then
    db="-setPass $setPass"
fi

if ! [ -z "$sshport" ]; then
    sshport="-sshport $sshport"
fi



echo "using following settings:" $hostname $certFile $db $debug $https $keyFile $listenip $listenport $reverseProxy $reverseProxyPort $setEdition $setPass $sshport

/app/c2_community-linux-64 $hostname $certFile $db $debug $https $keyFile $listenip $listenport $reverseProxy $reverseProxyPort $setEdition $setPass $sshport
