#!/bin/bash

# The name comes from "There's a hole in the bucket, dear liza" - and the program drains the GCP logs from the GCP sink bucket... ;)
start=$SECONDS
clear

# empty the log file
> /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/logprep_results.logprep_results

. ./functions.sh


# clean up from the last run and refresh the GCP logs
[[ -e /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/2020 ]] && rm -R /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/2020
> /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/xfers.log.csv

# tell gsutil to copy the whole bucket down
gsutil -m cp -L /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/xfers.log.csv -r -n gs://driveshaft_operations_logs/stdout/* /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs

# these should really be CLI switches
fixJSON=true
convertCSV=true

# process the log files
for f in /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/2020/**/**/*.json
	do
		echo "====================================> " $f
		# GCP log files are created once per hour for the preceding hour. Each line is a full JSON log entry
		# and in order to use ea typical JSON parser (csvkit acts on files, not lines, by default), we need to
		# add [] as first/last char and term each line with a comma. Then it's a fully formed JSON file.

		# check if the JSON file starts with a square bracket - if so it's already an array... otherwise fix it and test
		if [[ $fixJSON ]] && ! grep --quiet '^\[' $f; then
			sed -i '' -e '1s|^|[|' -e 's|}$|},|' -e '$s|,$|]|' $f
			python -m json.tool $f &>/dev/null && echo "$f: is now a JSON array"
		fi

		if [[ $convertCSV ]]; then
			#create a CSV file for each JSON file
			in2csv $f > $f.csv && echo $f.csv has been created

			# if the CSV has a column named 'jsonPayload/driveshaft_response/cluster/name',
			# it's one of the records I want to save, so copy those records to a new .csv file
			if grep --quiet "jsonPayload/driveshaft_response/cluster/name" $f.csv; then
				echo $f.csv - found getavailable records
				csvcut -c "insertId","jsonPayload/driveshaft_response/cluster/name","jsonPayload/driveshaft_response/cluster/rdmId","jsonPayload/driveshaft_response/cluster/requestId","jsonPayload/ip","jsonPayload/operation","jsonPayload/user_id","jsonPayload/timestamp","receiveTimestamp" $f.csv | \
				csvgrep -c "jsonPayload/operation" -m getavailable > $f.getavailable.csv
			else
				echo $f does not contain any getavailable records
			fi

			# same for 'jsonPayload/driveshaft_response/requestId', but in a different CSV file
			if grep --quiet "jsonPayload/driveshaft_response/requestId" $f.csv; then
				echo $f.csv - found release records
				# for release
				csvcut -c "insertId","jsonPayload/driveshaft_response/requestId","jsonPayload/ip","jsonPayload/operation","receiveTimestamp","jsonPayload/timestamp" $f.csv | \
				csvgrep -c "jsonPayload/operation" -m release > $f.release.csv
			else
				echo $f.csv does not contain any release records
			fi
			
		fi

		# here for future use... reverses the changes made to GCP's pseudo-JSON log files.
		# if [[ $reverse ]] && python -m json.tool $f &>/dev/null; then
		# 	echo $f: yes
		# 	sed -i '' -e '1s|^\[||' -e 's|\},$|\}|' -e '$s|\]$||' $f && echo "$f: is now no"
		# fi
		echo
	done

# stack the getavailable files into a single csv file and then write to the DB
echo "Stacking getavailable requests into /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/getavailable.csv"
# empty the output file
> /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/getavailable.csv
# exec csvstack against the list of found csv files
find /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/2020 -name '*.getavailable.csv' -exec csvstack {} > /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/getavailable.csv +
# normalize the column names in the output CSV - col name formats are /foo/bar/fiddle (represents key names in original JSON) - strip all but the last word in the col names
sed -i '' '1s|[[:alnum:]_]*/||g' /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/getavailable.csv && echo "Fixed column names in getavailable.csv."
# send the contents of the output CSV to the MySQL DB running locally
csvsql --db mysql+mysqlconnector://root:@127.0.0.1:3306/udacity_logs --tables getavailable --insert --overwrite getavailable.csv && echo "Pushing getavailable data to the MySQL database."
echo

# same process as above only for a different output file
echo "Stacking release requests into /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/release.csv"
> /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/release.csv
find /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/2020 -name '*.release.csv' -exec csvstack {} > /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/release.csv +
sed -i '' '1s|[[:alnum:]_]*/||g' /Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs/release.csv && echo "Fixed column names in release.csv."
csvsql --db mysql+mysqlconnector://root:@127.0.0.1:3306/udacity_logs --tables release --insert --overwrite release.csv && echo "Pushing release data to the MySQL database."
echo


echo "Processed $(find 2020 -name "*.json" | wc -l) files in $(convertsecs2hms $(( SECONDS-start)) )."


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
