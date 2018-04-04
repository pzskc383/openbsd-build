#!/bin/sh
set -eu
CVSROOT="anoncvs@anoncvs.eu.openbsd.org:/cvs"

log() {
	prefix=$1; shift
	logger -p local1.info "${prefix}: ${@}" >/dev/null 2>&1
}

wait_for_pids() {
	cont=1
	while [ $cont -gt 0 ]; do
		sleep 5;
		for pid in ${pids}; do
			if ! ps -p $pid >/dev/null; then
				cont=0
				break;
			fi
		done
	done
}

rcvs() {
    env HOME=/var/srcfetch \
        doas -u srcfetch \
	cvs -d${CVSROOT} "$@" 2>&1 |log srcfetch-cvs
}

rgit() {
    env HOME=/var/srcfetch \
        doas -u srcfetch \
	git "$@" 2>&1 |log srcfetch-git
}

echo "updating /usr/{src,xenocara, ports}"
pids=""
cd /usr/src
rcvs -q up -Pd &
pids="$!"

cd /usr/xenocara
rcvs -q up -Pd &
pids="$pids $!"

cd /usr/ports
rcvs -q up -Pd &
pids="$pids $!"

wait_for_pids
echo "Done"

echo "updating openbsd-wip && custom ports"
cd /usr/local/ports/gh-wip
rgit pull --rebase & 
pids="$!"

cd /usr/local/ports/my 
rgit pull --rebase &
pids="${pids} $!"

wait_for_pids
echo "Done"
