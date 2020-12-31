#!/bin/bash

# The name comes from "There's a hole in the bucket, dear liza" - and the program drains the GCP logs from the GCP sink bucket... ;)
start=$SECONDS
clear

# exit when any command fails
# set -e

# keep track of the last executed command
# trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
# trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

. ./env.sh
. ./functions.sh

if $clean; then
	# clean up from the last run and refresh the GCP logs
	[[ -e $logRoot ]] && rm -R $logRoot
	> $gcpXferLog
fi

# tell gsutil to copy the whole bucket down
gsutil -m cp -L $gcpXferLog -r -n $gcpBucketURL/$gcpLogName/* $rootPath


# process the log files
for f in $logRoot/**/**/*.json
	do
		echo "====================================> " $f
		# GCP log files are created once per hour for the preceding hour. Each line is a full JSON log entry
		# and in order to use ea typical JSON parser (csvkit acts on files, not lines, by default), we need to
		# add [] as first/last char and term each line with a comma. Then it's a fully formed JSON file.

		# check if the JSON file starts with a square bracket - if so it's already an array... otherwise fix it and test
		if [[ $fixJSON ]] && ! grep --quiet '^\[' $f; then
			sed -i '' -e '1s|^|[|' -e 's|}$|},|' -e '$s|,$|]|' $f
			python -m json.tool $f &>/dev/null && echo "$f: is now a JSON array"
		else
			echo "Skipping the JSON fix stage for $f"
		fi

		if [[ $convertCSV && ! -e $f.csv ]]; then
			#create a CSV file for each JSON file
			in2csv $f > $f.csv && echo $f.csv has been created

			# if the CSV has a column named 'jsonPayload/driveshaft_response/cluster/name',
			# it's one of the records I want to save, so copy those records to a new .csv file
			if grep --quiet "jsonPayload/driveshaft_response/cluster/name" $f.csv; then
				echo -e "\033[1;32m$f.csv - found GETAVAILABLE records\033[0m"
				csvcut -c "insertId","jsonPayload/driveshaft_response/cluster/name","jsonPayload/driveshaft_response/cluster/rdmId","jsonPayload/driveshaft_response/cluster/requestId","jsonPayload/ip","jsonPayload/operation","jsonPayload/user_id","jsonPayload/timestamp","receiveTimestamp" $f.csv | \
				csvgrep -c "jsonPayload/operation" -m getavailable > $f.getavailable.csv
			else
				echo -e "\033[1;31m$f.csv does not contain GETAVAILABLE records\033[0m"
			fi

			# same for 'jsonPayload/driveshaft_response/requestId', but in a different CSV file
			if grep --quiet "jsonPayload/driveshaft_response/requestId" $f.csv; then
				echo -e "\033[1;32m$f.csv - found RELEASE records\033[0m"
				# for release
				csvcut -c "insertId","jsonPayload/driveshaft_response/requestId","jsonPayload/ip","jsonPayload/operation","receiveTimestamp","jsonPayload/timestamp" $f.csv | \
				csvgrep -c "jsonPayload/operation" -m release > $f.release.csv
			else
				echo -e "\033[1;31m$f.csv does not contain RELEASE records\033[0m"
			fi
		else
			echo "Skipping the CSV creation stage for $f"
			
		fi

		# here for future use... reverses the changes made to GCP's pseudo-JSON log files.
		# if [[ $reverse ]] && python -m json.tool $f &>/dev/null; then
		# 	echo $f: yes
		# 	sed -i '' -e '1s|^\[||' -e 's|\},$|\}|' -e '$s|\]$||' $f && echo "$f: is now no"
		# fi
		echo
	done

# stack the getavailable files into a single csv file and then write to the DB
echo "Stacking getavailable requests into $rootPath/getavailable.csv"
# empty the output file
> $rootPath/getavailable.csv
# exec csvstack against the list of found csv files
find $logRoot -name '*.getavailable.csv' -exec csvstack {} >$rootPath/getavailable.csv +
# normalize the column names in the output CSV - col name formats are /foo/bar/fiddle (represents key names in original JSON) - strip all but the last word in the col names
sed -i '' '1s|[[:alnum:]_]*/||g' $rootPath/getavailable.csv   && echo "Fixed column names in $rootPath/getavailable.csv."
# send the contents of the output CSV to the MySQL DB running locally
csvsql --db $dbconnectstring --tables getavailable --insert --overwrite $rootPath/getavailable.csv && echo -e "\033[1;34mPushing getavailable data to the MySQL database \033[0;33m($(cat $rootPath/getavailable.csv | wc -l | xargs) records)\033[0m."
echo

# same process as above only for a different output file
echo "Stacking release requests into $rootPath/release.csv"
> $rootPath/release.csv
find $logRoot -name '*.release.csv' -exec csvstack {} > $rootPath/release.csv +
sed -i '' '1s|[[:alnum:]_]*/||g' $rootPath/release.csv && echo "Fixed column names in release.csv."
csvsql --db $dbconnectstring --tables release --insert --overwrite $rootPath/release.csv && echo -e "\033[1;34mPushing release data  to the MySQL database \033[0;33m($(cat $rootPath/release.csv | wc -l | xargs) records)\033[0m."
echo


echo -e "\033[0;33mProcessed \033[1;34m$(find $logRoot -name "*.json" | wc -l | xargs) \033[0;33mfiles in \033[1;34m$(convertsecs2hms $(( SECONDS-start)) )\033[0;33m.\033[0m"


# utility/testing below here


# for filename in 2020/12/09/*.json; do

# lncnt=0 
# echo $filename
# while read  -r  line; do        
#     lncnt=$((lncnt+1))      
#     echo "${line}" | python -m json.tool 
#     RET=$?
#     if  [ $RET -gt 0 ] ; then
#       echo "Error in $filename:$lncnt ${line}" 
#       break
#     fi
#   done < $filename
# done
