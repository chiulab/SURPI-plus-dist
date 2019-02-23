#!/bin/bash
#
#	host_subtract.sh
#
#	This script performs teh host subtraction portion of the pipeline.
#	Chiu Laboratory
#	University of California, San Francisco
#
#
# Copyright (C) 2014 Samia N Naccache, Scot Federman, and Charles Y Chiu - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.
#

expected_args=6
scriptname=${0##*/}

if [ $# -lt "$expected_args" ]
then
	echo "Usage: $scriptname <inputfile> <cores> <SNAP folder of databases to subtract> <SNAP_edit_distance> <outputfile (without extension)> <basef>"
	exit 65
fi

###
inputfile=$1
cores=$2
SNAP_subtraction_folder=$3
edit_distance=$4
outputfile=$5
basef=$6
###

file_to_subtract="$inputfile"			# $basef.preprocessed.fastq
subtracted_output_file="$outputfile"	# $basef_h.human.snap.unmatched.sam

SUBTRACTION_COUNTER=0

START_SNAP=$(date +%s)

for SNAP_subtraction_db in $SNAP_subtraction_folder/*
do
	SUBTRACTION_COUNTER=$[$SUBTRACTION_COUNTER +1]
	# check if SNAP db is cached in RAM, use optimal parameters depending on result
	SNAP_db_cached=$(vmtouch -m500G -f "$SNAP_subtraction_db" | grep 'Resident Pages' | awk '{print $5}')
	if [[ "$SNAP_db_cached" == "100%" ]]
	then
		echo -e "$(date)\t$scriptname\tSNAP database is cached ($SNAP_db_cached)."
		SNAP_cache_option=" -map "
	else
		echo -e "$(date)\t$scriptname\tSNAP database is not cached ($SNAP_db_cached)."
		SNAP_cache_option=" -pre -map "
	fi
	echo -e "$(date)\t$scriptname\tParameters: snap-dev single $SNAP_subtraction_db $file_to_subtract -o -sam $subtracted_output_file.$SUBTRACTION_COUNTER.sam -t $cores -x -f -h 250 -d ${edit_distance} -n 25 -F u $SNAP_cache_option"
	START_SUBTRACTION_STEP=$(date +%s)
	snap-dev single "$SNAP_subtraction_db" "$file_to_subtract" -o -sam "$subtracted_output_file.$SUBTRACTION_COUNTER.sam" -t "$cores" -x -f -h 250 -d "$edit_distance" -n 25 -F u $SNAP_cache_option
	END_SUBTRACTION_STEP=$(date +%s)
	echo -e "$(date)\t$scriptname\tDone: SNAP to $SNAP_subtraction_db"
	diff_SUBTRACTION_STEP=$(( END_SUBTRACTION_STEP - START_SUBTRACTION_STEP ))
	echo -e "$(date)\t$scriptname\tSubtraction step: $SUBTRACTION_COUNTER took $diff_SUBTRACTION_STEP seconds"
	file_to_subtract="$subtracted_output_file.$SUBTRACTION_COUNTER.sam"
done

#convert SAM file to fastq for input to SNAP to NT phase
egrep -v "^@" "$subtracted_output_file.$SUBTRACTION_COUNTER.sam" | awk '{if($3 == "*") print "@"$1"\n"$10"\n""+"$1"\n"$11}' > "${outputfile}.fastq"

if [[ $SURPI_DEBUG != "Y" ]]
then
	rm $subtracted_output_file.*.sam
fi

END_SNAP=$(date +%s)
diff_SNAP=$(( END_SNAP - START_SNAP ))
echo -e "$(date)\t$scriptname\tSNAP Subtraction took $diff_SNAP seconds" | tee -a "timing.$basef.log"
