#!/usr/bin/env bash

SERVERDIR=$(dirname "$0")
cd ${SERVERDIR}

PARAMS="$@"

CONFIGFILE=

while test $# -gt 0
do
  if [ $(echo $1 | cut -c 1-12) = "-configfile=" ]; then
    CONFIGFILE=$(echo $1 | cut -c 13-)
  fi

  shift
done

if [ "${CONFIGFILE}" = "" ]; then
  echo "No config file specified. Call this script like this:"
  echo ""
  echo "./startserver.sh -configfile=serverconfig.xml"
  echo ""
  exit 1
else
  if [ -f "${CONFIGFILE}" ]; then
    echo Using config file: $CONFIGFILE
  else
    echo "Specified config file $CONFIGFILE does not exist."
    exit 1
  fi
fi

export LD_LIBRARY_PATH=.
#export MALLOC_CHECK_=0

if [ "$(uname -m)" = "x86_64" ]; then
  ./7DaysToDieServer.x86_64 \
    -logfile $(pwd)/output-log__$(date +%Y-%m-%d__%H-%M-%S).log \
    -quit \
    -batchmode \
    -nographics \
    -dedicated $PARAMS
else
  echo "7 Days to Die only supports 64 bit operating systems!"
  exit 1
fi
