#!/bin/bash
#
#	bowtie2_subtract.sh
#
#	This script performs bowtie2 subtraction from a fastq
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

if [ $# -lt $expected_args ]
then
	echo "Usage: $scriptname <inputfile (without fastq extension)> <cores> <bowtie2 database> <outputfile (without fastq extension)> <basef> <fulllength readfile>"
	exit 65
fi

###
inputfile=$1
cores=$2
BOWTIE2_folder=$3
outputfile=$4
basef=$5
fulllength_reads=$6
###

file_to_subtract="${inputfile}.fulllength"

# Want to subtract using cutadapt reads rather than cropped, so:

#	1. Create FASTQ of cutadapt reads post SNAP SUBTRACTION

START_BOWTIE=$(date +%s)
# extract headers from $snap_subtraction_output.fastq
echo -e "$(date)\t$scriptname\tExtracting headers from ${inputfile}.fastq"
sed -n '1~4p' "${inputfile}.fastq" | sed "s/^@//g" > "${inputfile}.header"

# extract full-length reads using headers (from fulllength_reads file passed to this script)
echo -e "$(date)\t$scriptname\tExtracting full-length sequences"
cat "$fulllength_reads" | fqextract "${inputfile}.header" > "${file_to_subtract}.fastq"

END_FL_EXTRACT=$(date +%s)
diff_FL_EXTRACT=$(( END_FL_EXTRACT - START_BOWTIE ))
echo -e "$(date)\t$scriptname\tFull-length extraction took $diff_FL_EXTRACT seconds"



#	2. Align to desired databases using bowtie2.
#	The databases must have follow a specific naming scheme.
#	Folders within the BOWTIE2_FOLDER must have a name that is the database name they contain. See below for example:

# BOWTIE2_FOLDER="/reference/bowtie2/" # in config file
# 
# /reference/bowtie2/
#         database1/
#                 database1.1.bt
#                 database1.2.bt
#                 database1.3.bt
#                 database1.4.bt
#                 database1.rev.1.bt
#                 database1.rev.2.bt
#         database2/
#                 database2.1.bt
#                 database2.2.bt
#                 database2.3.bt
#                 database2.4.bt
#                 database2.rev.1.bt
#                 database2.rev.2.bt

SUBTRACTION_COUNTER=0

# want to count folders (-type d) or softlinks (-type l)
TOTAL_TO_SUBTRACT=$(find $BOWTIE2_folder/* -maxdepth 2 \( -type d -o -type l \) | wc -l)
echo -e "$(date)\t$scriptname\tTotal bt2 dbs to subtract: $TOTAL_TO_SUBTRACT"

START_BOWTIE=$(date +%s)
for BOWTIE2_PATH in $BOWTIE2_folder/*
do
	db_name=$(basename "$BOWTIE2_PATH")
	SUBTRACTION_COUNTER=$[$SUBTRACTION_COUNTER +1]
	echo -e "$(date)\t$scriptname\tbowtie2 --very-sensitive-local --no-sq -p $cores -x $BOWTIE2_PATH/$db_name ${file_to_subtract}.fastq --un ${file_to_subtract}.bt2.unmatched.$SUBTRACTION_COUNTER.fastq --al ${file_to_subtract}.bt2.matched.$SUBTRACTION_COUNTER.fastq -S ${file_to_subtract}.bt2.$SUBTRACTION_COUNTER.sam"
	START_BOWTIE_STEP=$(date +%s)
	bowtie2 --very-sensitive-local --no-sq -p "$cores" -x "$BOWTIE2_PATH/$db_name" "${file_to_subtract}.fastq" --un "${file_to_subtract}.bt2.unmatched.$SUBTRACTION_COUNTER.fastq" --al "${file_to_subtract}.bt2.matched.$SUBTRACTION_COUNTER.fastq" -S "${file_to_subtract}.bt2.$SUBTRACTION_COUNTER.sam"
	END_BOWTIE_STEP=$(date +%s)
	diff_BOWTIE_STEP=$(( END_BOWTIE_STEP - START_BOWTIE_STEP ))
	if [[ "$SUBTRACTION_COUNTER" -ne "$TOTAL_TO_SUBTRACT" ]]
	then
		file_to_subtract="${file_to_subtract}.bt2.unmatched.$SUBTRACTION_COUNTER"
	fi
	echo -e "$(date)\t$scriptname\tBowtie2 Subtraction step: $SUBTRACTION_COUNTER took $diff_BOWTIE_STEP seconds"
done
END_BOWTIE=$(date +%s)
diff_BOWTIE=$(( END_BOWTIE - START_BOWTIE ))
echo -e "$(date)\t$scriptname\tBowtie2 Subtraction took $diff_BOWTIE seconds"


# Now have 3 files:
# ${file_to_subtract}.bt2.unmatched.$SUBTRACTION_COUNTER.fastq		- propagates through pipeline
# ${file_to_subtract}.bt2.matched.$SUBTRACTION_COUNTER.fastq		- currently used for reference & troubleshooting, can eventually be removed, or not created
# ${file_to_subtract}.bt2.$SUBTRACTION_COUNTER.sam					- currently used for reference & troubleshooting, can eventually be removed, or not created

#	3. Pull cropped reads of the bt2 unmatched to move through pipeline
# "${file_to_subtract}.bt2.unmatched.fastq" contains fl reads (post-subtraction). pull cropped reads out using fqextract & save to $outputfile.

START_CROP_EXTRACT=$(date +%s)
# extract headers from ${file_to_subtract}.bt2.unmatched.fastq
echo -e "$(date)\t$scriptname\tExtracting headers from ${file_to_subtract}.bt2.unmatched.$SUBTRACTION_COUNTER.fastq"
sed -n '1~4p' "${file_to_subtract}.bt2.unmatched.$SUBTRACTION_COUNTER.fastq" | sed "s/^@//g" > "${file_to_subtract}.bt2.unmatched.header"

# extract cutadapt reads using headers (from inputfile file passed to this script)
echo -e "$(date)\t$scriptname\tExtracting cropped sequences"
cat "${inputfile}.fastq" | fqextract "${file_to_subtract}.bt2.unmatched.header" > "$outputfile"
END_CROP_EXTRACT=$(date +%s)
diff_CROP_EXTRACT=$(( END_CROP_EXTRACT - START_CROP_EXTRACT ))
echo -e "$(date)\t$scriptname\tCrop extraction took $diff_CROP_EXTRACT seconds"

if [[ "$SURPI_DEBUG" != "Y" ]]
then
	rm "${inputfile}.header"
	rm "${inputfile}.fulllength.fastq"
	rm "${file_to_subtract}.bt2.unmatched.header"
fi

END_BOWTIE=$(date +%s)
diff_BOWTIE=$(( END_BOWTIE - START_BOWTIE ))
echo -e "$(date)\t$scriptname\tBowtie2 procedure took $diff_BOWTIE seconds" | tee -a "timing.$basef.log"
