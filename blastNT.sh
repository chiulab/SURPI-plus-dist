#!/bin/bash
#
#	blastNT.sh
#
#	RUNS BLAST TO NT and then outputs hits
#	Chiu Laboratory
#	University of California, San Francisco
#
#
# Copyright (C) 2014 Charles Y Chiu - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.
#

scriptname=${0##*/}

if [ $# -lt 5 ]
then
    echo "Usage: $scriptname <FASTA file> <output BLASTN file> <e value> <BLAST_folder> <cores>"
    exit
fi

nopathf=${1##*/}
basef=${nopathf%.fasta}

###
input_file=$1
output_file=$2
e_value=$3
BLAST_folder=$4
cores=$5
###

BLAST_databases="nt.00 nt.01 nt.02 nt.03 nt.04 nt.05 nt.06 nt.07 nt.08 nt.09 nt.10 nt.11 nt.12 nt.13 nt.14 nt.15 nt.16 nt.17 nt.18 nt.19 nt.20 nt.21"
if [ ! -f $input_file ]
then
    echo "$input_file not found!"
    exit
fi

echo -e "$(date)\t$scriptname\tSplitting $input_file..."
let "numlines = `wc -l $input_file | awk '{print $1}'`"
let "FASTAentries = numlines / 2"
echo -e "$(date)\t$scriptname\tThere are $FASTAentries FASTA entries in $basef"
let "LinesPerCore = numlines / $cores"
let "FASTAperCore = LinesPerCore / 2 + 1" # much slower w/o + 1

if [[ "$FASTAperCore" -eq 0 ]]; then
    echo -e "$(date)\t$scriptname\tWill use 1 core"
    cp "$inputfile" "$input_file.blastn00"
else
    let "SplitPerCore = FASTAperCore * 2"
    echo -e "$(date)\t$scriptname\tWill use $cores cores with $FASTAperCore entries per core"
    split -l "$SplitPerCore" "$input_file" "$input_file.blastn"
fi

echo -e "$(date)\t$scriptname\trunning BLASTn on $basef.fasta..."
for f in `ls $input_file.blastn??`
do
	for ntfile in $BLAST_databases
	do
		blastn -task blastn -db "${BLAST_folder}/${ntfile}" -query $f -evalue $e_value -num_threads 1 -num_descriptions 5 -num_alignments 5 -culling_limit 5 -out $f.$ntfile.blastn -outfmt 6 >& blast.$f.$ntfile.log &
		####### must turn off filtering! (low-complexity monkeypox sequences) ######
	done
done

for job in `jobs -p`
do
	wait $job
done

echo -e "$(date)\t$scriptname\tdone BLAST for each chunk..."

echo -e "$(date)\t$scriptname\twriting BLASTN hits to $output_file"

rm -f $output_file

for f in `ls $input_file.blastn??`
do
	for ntfile in $BLAST_databases
	do
		cat $f.$ntfile.blastn >> $output_file
		cat blast.$f.$ntfile.log >> $output_file.log
		rm -f $f.$ntfile.blastn
		rm -f blast.$f.$ntfile.log
		rm -f $f
	done
done
