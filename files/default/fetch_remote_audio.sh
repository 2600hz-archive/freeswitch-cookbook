#!/bin/bash

URL=$1
TYPE="wav"
shift 1

# echo "# curl -f $URL | sox -t $TYPE - $@ -t raw -" >> /tmp/fetch_remote_audio.log
curl -f $URL | sox -t $TYPE - $@ -t raw -
