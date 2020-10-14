#!/bin/bash

BENCHMARK=${1-`pwd`}
DBFOLDER=${2-`pwd`/databases}
TMP=/tmp/nosqlbenchmark
DOWNLOADS=$TMP/downloads

mkdir -p $DBFOLDER
mkdir -p $DOWNLOADS

## ArangoDB
./arangodb/setup.sh $BENCHMARK $DBFOLDER $TMP
sleep 5
./arangodb_mmfiles/setup.sh $BENCHMARK $DBFOLDER $TMP

