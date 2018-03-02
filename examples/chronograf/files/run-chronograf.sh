#!/bin/bash

#
# License: https://github.com/cadeworks/cade/blob/master/LICENSE
#

set -e

echo "[cade chronograf] starting..."

if [ -z "$PUBLIC_HOST_IP" ];
then
    internal_ip=${CONTAINER_IP}
else
    internal_ip="0.0.0.0"
fi

echo "[cade chronograf] starting chronograf on ${CONTAINER_IP}"
# vagrant@build:~$ /opt/chronograf/usr/bin/chronograf --help
# Usage:
#   chronograf [OPTIONS]
#
# Options for Chronograf
#
# Application Options:
#       --host=                                                  the IP to listen on (default: 0.0.0.0) [$HOST]
#       --port=                                                  the port to listen on for insecure connections, defaults to a random value (default: 8888) [$PORT]
#   -d, --develop                                                Run server in develop mode.
#   -b, --bolt-path=                                             Full path to boltDB file (/var/lib/chronograf/chronograf-v1.db) (default: chronograf-v1.db) [$BOLT_PATH]
#   -c, --canned-path=                                           Path to directory of pre-canned application layouts (/usr/share/chronograf/canned) (default: canned) [$CANNED_PATH]
#   -t, --token-secret=                                          Secret to sign tokens [$TOKEN_SECRET]
#   -i, --github-client-id=                                      Github Client ID for OAuth 2 support [$GH_CLIENT_ID]
#   -s, --github-client-secret=                                  Github Client Secret for OAuth 2 support [$GH_CLIENT_SECRET]
#   -r, --reporting-disabled                                     Disable reporting of usage stats (os,arch,version,cluster_id) once every 24hr [$REPORTING_DISABLED]
#   -l, --log-level=choice[debug|info|warn|error|fatal|panic]    Set the logging level (default: info) [$LOG_LEVEL]
#   -v, --version                                                Show Chronograf version info
#
# Help Options:
#   -h, --help                                                   Show this help message
/opt/chronograf/usr/bin/chronograf --host=${internal_ip} -b /data/chronograf-v1-boltdb.db -c /opt/chronograf/usr/share/chronograf/canned


