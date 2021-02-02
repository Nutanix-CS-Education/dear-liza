#!/bin/bash

. ./env.sh
. ./functions.sh


# process the log files
for d in ${logRootDirs[@]}
	do
		for f in ${rootPath}/${d}/**/**/*.json.csv
			do
				echo "====================================> " $f
				csvgrep -c "jsonPayload/operation" -m release $f && [[ $(csvgrep -c "jsonPayload/ex" -r '.*?' $f)  || $(csvgrep -c "jsonPayload/err" -r '.*?' $f) ]] && echo "FOUND RELEASE ERRORS IN: $f"
			done
done
