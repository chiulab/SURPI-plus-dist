#!/bin/bash
#
#	dust_masker.sh
#
# 	uses dustmasker to remove low complexity reads from .annotated files
#	Chiu Laboratory
#	University of California, San Francisco
#
#
# Copyright (C) 2014 Charles Y Chiu - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.
#

scriptname=${0##*/}

if [ $# != 2 ]
then
	echo "Usage: $scriptname <1.annotated> <output>"
	exit
fi

nopathf=${1##*/}
basef=${nopathf%.annotated}

###
input=$1
output=$2
###

if [ ! -f $input ]
then
	echo "$input not found!"
	exit
fi

echo -e "$(date)\t$scriptname\tStarting creation of FASTA file..."
awk '{printf(">%s\n%s\n",$1,$10)}' "$input" > "$input.fasta"
echo -e "$(date)\t$scriptname\tCompleted creation of FASTA file."

echo -e "$(date)\t$scriptname\tStarting dustmasker on $input.fasta..."
dustmasker -in "$input.fasta" -outfmt fasta > "$input.dust.fasta"
echo -e "$(date)\t$scriptname\tCompleted dustmasker on $input.fasta."

# converts multi-line FASTA to single-line FASTA, identifies masked reads, deletes them, and then selects remaining headers
cat "$input.dust.fasta" | awk '/^>/{print s? s"\n"$0:$0;s="";next}{s=s sprintf("%s",$0)}END{if(s)print s}' | sed "n;/[acgt]/d" | awk 'BEGIN {RS = ">" ; FS = "\n" ; ORS = ""} {if ($2) print ">"$0}' | grep ">" | sed "s/>//g" > "$input.dust.headers"
# looks up the headers
awk 'FNR==NR { a[$1]=$1; next} $1 in a {print $0}' "$input.dust.headers" "$input" > "$output"

# clean up script
rm -f $input.fasta
rm -f $input.dust.fasta
rm -f $input.dust.headers
