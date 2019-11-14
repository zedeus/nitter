#!/bin/sh

set -e
set -u

BUILD=/build
WORKD=/data

build_working_dir() {
    [ -f $WORKD/nitter.conf ] || cp -f  $BUILD/nitter.conf $WORKD/.
    [ -d $WORKD/public ]      || cp -rf $BUILD/public      $WORKD/.
}

# -- program starts

build_working_dir

# If we have an interactive container session
if [[ -t 0 || -p /dev/stdin ]]; then
    if [[ $@ ]]; then 
	eval "exec $@"
    else 
	export PS1='[\u@\h : \w]\$ '
	exec /bin/sh
    fi
# If container is detached run nitter in the foreground
else
    if [[ $@ ]]; then 
	eval "exec $@"
    else
	cd $WORKD
	exec /usr/local/bin/nitter
    fi
fi
