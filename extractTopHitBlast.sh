#!/bin/bash
#
#	extractTopHitBlast.sh
#
#	extracts the top hit from a blast output
#	Chiu Laboratory
#	University of California, San Francisco
#
#
# Copyright (C) 2014 Charles Y Chiu - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.

scriptname=${0##*/}

if [ $# -lt 2 ]
then
	echo "Usage: $scriptname <blast file (input)> <top hit blast file (output)>"
	exit
fi

if [ ! -f $1 ]
then
	echo "$1 not found!"
	exit
fi

echo -e "$(date)\t$scriptname\tStarting $scriptname..."

START1=$(date +%s)
# randomize BLAST output, then select top hit; ties are treated randomly
awk 'BEGIN {srand()} {printf "%05.0f\t%s\n",rand()*999999999, $0; }' $1 | sort -n | cut -f2- > $1.rand
cat $1.rand | sort -k12,12nr -s | sort -k1,1 -s | sort -u -k1,1 -s --merge > $2
END1=$(date +%s)

echo -e "$(date)\t$scriptname\tFinished $scriptname."
diff=$(( END1 - START1 ))
echo -e "$(date)\t$scriptname\t$scriptname took $diff seconds"