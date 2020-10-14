#!/bin/bash

which=$1
FN=$2
DBFOLDER=${3-`pwd`/databases}

sudo bash -c "
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo 1 > /proc/sys/net/ipv4/tcp_fin_timeout
echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
"

ulimit -n 60000

WATCHER_PID=/tmp/watcher.pid

# comm cputime etimes rss pcpu
export AWKCMD='{a[$1] = $1; b[$1] = $2; c[$1] = $3; d[$1] = $4; e[$1] = $5} END {for (i in a) printf "%s; %s; %s; %0.1f; %0.1f\n", a[i], b[i], c[i], d[i], e[i]}'

killPIDFile() {
    PID_FN=$1
    if test -f ${PID_FN}; then
        PID=`cat ${PID_FN}`
        kill ${PID} 2> /dev/null
        count=0
        while test -d /proc/${PID}; do
            echo "."
            sleep 1
            count=$((${count} + 1))
            if test "${count}" -gt 60; then
                kill -9 ${PID}
            fi
        done
        rm -f ${PID_FN}
    fi
}


stop_ArangoDB() {
    killPIDFile "/tmp/arangodb.pid"
}

start_ArangoDB_mmfiles() {
    ADB=${DBFOLDER}/arangodb
    cd ${ADB}
    ${ADB}/usr/sbin/arangod \
        ${ADB}/pokec-mmfiles \
        --pid-file /tmp/arangodb.pid \
        --log.file /var/tmp/arangodb.log \
        --temp.path `pwd` \
        --working-directory `pwd` \
        --daemon \
        --configuration ${ADB}/etc/arangodb3/arangod.conf \
        --server.authentication false \
        --javascript.app-path ${ADB}/apps \
        --javascript.startup-directory ${ADB}/usr/share/arangodb3/js \
        --server.storage-engine mmfiles || (echo "failed" && exit 1)

    while ! curl http://288fcfd50c6c.arangodb.cloud:8529/_api/version -fs ; do sleep 1 ; done

    nohup bash -c "
while true; do
    sleep 1
    echo -n \"`date`; \"
    ps -p `cat /tmp/arangodb.pid` -o 'comm cputime etimes rss pcpu' --no-headers | \
        awk '${AWKCMD}'
done > $FN 2>&1" > /dev/null 2>&1 &

    echo "$!" > "${WATCHER_PID}"
}
 
start_ArangoDB() {
    ADB=${DBFOLDER}/arangodb
    cd ${ADB}
    ${ADB}/usr/sbin/arangod \
        ${ADB}/pokec-rocksdb \
        --pid-file /tmp/arangodb.pid \
        --log.file /var/tmp/arangodb.log \
        --temp.path `pwd` \
        --working-directory `pwd` \
        --daemon \
        --wal.sync-interval 1000 \
        --configuration ${ADB}/etc/arangodb3/arangod.conf \
        --server.authentication false \
        --javascript.app-path ${ADB}/apps \
        --javascript.startup-directory ${ADB}/usr/share/arangodb3/js \
        --server.storage-engine rocksdb || (echo "failed" && exit 1)

    while ! curl http://288fcfd50c6c.arangodb.cloud:8529/_api/version -fs ; do sleep 1 ; done

    nohup bash -c "
while true; do
    sleep 1
    echo -n \"`date`; \"
    ps -p `cat /tmp/arangodb.pid` -o 'comm cputime etimes rss pcpu' --no-headers | \
        awk '${AWKCMD}'
done > $FN 2>&1" > /dev/null 2>&1 &

    echo "$!" > "${WATCHER_PID}"
}




echo "================================================================================"
echo "* stopping databases"
echo "================================================================================"

stop_ArangoDB

killPIDFile "${WATCHER_PID}"

echo "================================================================================"
echo "* starting: $which $version"
echo "================================================================================"

case "$which" in
arangodb_mmfiles)
    start_ArangoDB_mmfiles
    ;;
arangodb)
    start_ArangoDB
    ;;
*)
    echo "unsupported database: [$which]"
    echo "I know: ArangoDB, ArangoDB_mmfiles"
    exit 1
    ;;
esac

