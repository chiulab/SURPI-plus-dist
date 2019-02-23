#!/bin/bash
#
#	snap-dev_nt_combine.sh
#
#	This script runs SNAP against the NT database
#
#	Chiu Laboratory
#	University of California, San Francisco
#
# This script will successively run SNAP against NT partitions and then combine the results
#
# Copyright (C) 2014 Charles Chiu - All Rights Reserved
# Permission to copy and modify is granted under the BSD license

expected_args=7
scriptname=${0##*/}

if [ $# -lt $expected_args ]
then
	echo "Usage: $scriptname <FASTQ input file> <directory containing SNAP NT indexes - no trailing forward slash> <number of cores> <SNAP d-value cutoff> <taxonomy_db_directory> <snap_omax> <snap_om>"
	exit 65
fi

###
inputfile=$1
SNAP_NT_index_directory=$2
cores=$3
SNAP_d_cutoff=$4
taxonomy_db_directory=$5
SNAP_omax=$6
SNAP_om=$7
###

echo -e "$(date)\t$scriptname\tStarting SNAP to NT"
START1=$(date +%s)

echo -e "$(date)\t$scriptname\tInput file: $inputfile"
nopathf=${inputfile##*/} # remove the path to file
echo -e "$(date)\t$scriptname\tAfter removing path: $nopathf"
basef=${nopathf%.fastq} # remove FASTQextension
echo -e "$(date)\t$scriptname\tAfter removing FASTQ extension: $basef"

echo -e "$(date)\t$scriptname\tMapping $basef to NT..."

#As of SNAP_1.0dev71, the default value for -D is 2. SNAP requires that -om is no greater than -D, so adjust -D to match -om if necessary
SNAP_depth=2

if [[ "$SNAP_om" -gt "$SNAP_depth" ]]
then
	SNAP_depth="$SNAP_om"
fi

for snap_index in $SNAP_NT_index_directory/*
do
	START2=$(date +%s)
	nopathsnap_index=${snap_index##*/} # remove the path to file
	echo -e "$(date)\t$scriptname\tStarting SNAP on $nopathsnap_index"

	# check if SNAP db is cached in RAM, use optimal parameters depending on result
	SNAP_db_cached=$(vmtouch -f -m500G "$SNAP_NT_index_directory" | grep 'Resident Pages' | awk '{print $5}')
	if [[ "$SNAP_db_cached" == "100%" ]]
	then
		echo -e "$(date)\t$scriptname\tSNAP database is cached ($SNAP_db_cached)."
		SNAP_cache_option=" -map "
	else
		echo -e "$(date)\t$scriptname\tSNAP database is not cached ($SNAP_db_cached)."
		SNAP_cache_option=" -pre -map "
	fi

	START_SNAP=$(date +%s)
	/usr/bin/time -o $basef.$nopathsnap_index.snap.log \
		snap-dev single "$snap_index" "$basef.fastq" \
			-o -samNoSQ "$basef.$nopathsnap_index.sam" \
			-t "$cores" \
			-x \
			-h 250 \
			-d "$SNAP_d_cutoff" \
			-om "$SNAP_om" \
			-D "$SNAP_depth" \
			-n 100 \
			-omax "$SNAP_omax" \
			-mpc 1 \
			-= \
			$SNAP_cache_option > "$basef.$nopathsnap_index.time.log"
	SNAP_DONE=$(date +%s)
	snap_time=$(( SNAP_DONE - START_SNAP ))
	echo -e "$(date)\t$scriptname\tCompleted running SNAP using $snap_index in $snap_time seconds."

	echo -e "$(date)\t$scriptname\tRemoving unmatched..."
	START_REMOVAL_UNMATCHED=$(date +%s)
	grep 'gi|' "$basef.$nopathsnap_index.sam" > "$basef.$nopathsnap_index.matched.sam"
	END_REMOVAL_UNMATCHED=$(date +%s)
	unmatched_removal_time=$(( END_REMOVAL_UNMATCHED - START_REMOVAL_UNMATCHED ))
	echo -e "$(date)\t$scriptname\tCompleted removing unmatched in $unmatched_removal_time seconds."

	# rm SNAP output with mixed matched/unmatched to reduce disk space needed
	if [[ -e "$basef.$nopathsnap_index.sam" ]]
	then
		rm "$basef.$nopathsnap_index.sam"
	fi

	END2=$(date +%s)
	diff=$(( END2 - START2 ))
	echo -e "$(date)\t$scriptname\tMapping to $snap_index took $diff seconds"
done

sam_matched_files=""
for snap_index in $SNAP_NT_index_directory/*
do
	nopathsnap_index=${snap_index##*/} # remove the path to file
	sam_matched_files="$sam_matched_files $basef.$nopathsnap_index.matched.sam"
done

output_file="$basef.NT.tax.sam"
echo -e "$(date)\t$scriptname\tStarting classification process..."
START_CLASSIFICATION=$(date +%s)

if [[ $SSD = 1 ]]
then
	echo -e "$(date)\t$scriptname\tclassify -parallel -output $output_file $taxonomy_db_directory $sam_matched_files"
	#Don't quote $sam_matched_files
	classify -parallel -output "$output_file" "$taxonomy_db_directory" $sam_matched_files

else
	echo -e "$(date)\t$scriptname\tclassify -output $output_file $taxonomy_db_directory $sam_matched_files"
	#Don't quote $sam_matched_files
	classify -output "$output_file" "$taxonomy_db_directory" $sam_matched_files
fi

END_CLASSIFICATION=$(date +%s)
classification_time=$(( END_CLASSIFICATION - START_CLASSIFICATION ))
echo -e "$(date)\t$scriptname\tCompleted classification: $classification_time seconds."

if [[ $SURPI_DEBUG != "Y" ]]
then
	for snap_index in $SNAP_NT_index_directory/*
	do
	# 	delete intermediate SAM files
		nopathsnap_index=${snap_index##*/} # remove the path to file
		if [[ -e "$basef.$nopathsnap_index.sam" ]]
		then
			rm "$basef.$nopathsnap_index.sam"
		fi
		if [[ -e "$basef.$nopathsnap_index.matched.sam" ]]
		then
			rm "$basef.$nopathsnap_index.matched.sam"
		fi
	done
fi

END1=$(date +%s)
diff=$(( END1 - START1 ))
echo -e "$(date)\t$scriptname\tOutput written to $basef.NT.tax.sam"
echo -e "$(date)\t$scriptname\tSNAP_NT Alignment and Classification took $diff seconds"
