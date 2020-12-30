#!/bin/bash

# these should really be CLI switches!
# converts JSON files to full JSON arrays by prepending [ to the file, appending a comma to each line, and appending ] to the end of the file
export fixJSON=true
# tells the system to use csvkit to convert the JSON array files to csv files and then search the csv files for relevant records
export convertCSV=true
# normally the script will only download the files that gsutil has not previously downloaded... doing a clean blows away the log and the cache first
# causing the system to re-download the whole shebang
export clean=true

# this root will be the path that contains the root folder of the copied log files
export rootPath=/Users/jared.rypkahauer/Developer/Node.js/td3-driveshaft/gcp/logs
# Just a helper for the processing phase - eveentually remove or replace
export logRoot=$rootPath/2020
# for connecting csvsql to the DB to save the log files
export dbconnectstring=mysql+mysqlconnector://root:@127.0.0.1:3306/udacity_logs
# A CSV file that GCP and gsutil uses to determine which files have been downloaded and which are new
export gcpXferLog=$rootPath/xfers.log.csv
# the URL for the GCP bucket - assumes you have proper credentials and are logged in
# * the full URL from which the log files will be retrieved is: $gcpBucketURL/$gcpLogName/*
export gcpBucketURL=gs://driveshaft_operations_logs
# the name of the log file you wish to gulp*
export gcpLogName=stdout
