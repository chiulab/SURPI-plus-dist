#!/bin/bash
#
#	NCBI_name_to_gb.sh
#
#	This program will extract a list of Genbank identifiers for a given NCBI taxonomical unit name.
#	Chiu Laboratory
#	University of California, San Francisco
#
#
# Copyright (C) 2014 Scot Federman - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.

scriptname=${0##*/}
bold=$(tput bold)
normal=$(tput sgr0)
optspec=":d:n:ghlt:pq:"

while getopts "$optspec" option; do
	case "${option}" in
		g) GI=1;;
		h) HELP=1;;
		n) name=${OPTARG};;
		t) taxid=${OPTARG};;
		d) type=${OPTARG};;
		l) direct_links=1;;
		p) PIPELINE=1;;
		q) taxonomy_folder=${OPTARG};;
		:)	echo "Option -$OPTARG requires an argument." >&2
			exit 1
      		;;
	esac
done

if [[ $HELP -eq 1  ||  $# -lt 2 ]]
then
	cat <<USAGE

${bold}${scriptname}${normal}

This program will extract a list of Genbank identifiers for a given NCBI taxonomical unit name.

${bold}Command Line Switches:${normal}

	-h	Show this help & ignore all other switches

	-g	Base databases on GI numbers (default: use accession)

	-n	Specify name

	-t	Specify taxid

	-d	Specify molecular type (nucl/prot)
	
	-l	Return only direct gb, no subtree
		By default, this program will return all gb for the taxid corresponding to the
		name (given by -n option), and all gb for the child taxid. If only gb classified 
		directly by the name are desired, use the -d option.

	-p	Pipeline mode
		Return gb list to stdout for use in a pipeline

	-q	folder containing taxonomy databases
		This folder should contain the 3 SQLite files created by the script "create_taxonomy_db.sh"
			(acc|gi)_taxid_nucl.db - nucleotide db of (acc|gi)/taxonid
			(acc|gi)_taxid_prot.db - protein db of (acc|gi)/taxonid
			names_nodes_scientific.db - db of taxonid/taxonomy

${bold}Usage:${normal}

	Extract list of nucleotide gi for a Zaire Ebolavirus:
		$scriptname -g -n "Zaire ebolavirus" -d nucl

	Extract list of protein accessions for a Zaire Ebolavirus:
		$scriptname -n "Zaire ebolavirus" -d prot

USAGE
	exit
fi

# pass flag to indicate GI instead of accession for Genbank identifier
if [[ ${GI} -eq 1 ]]; then
	gb="-g"
else
	gb=""
fi

if [[ $taxonomy_folder ]]
then
	names_nodes_db="$taxonomy_folder/names_nodes_scientific.db"
else
	echo "You need to supply the taxonomy folder location using -q."
	exit
fi

if [[ ! -r $names_nodes_db ]]
then
	echo "names_nodes_scientific.db not found in: $taxonomy_folder."
	echo "Please verify location and specify using -q option."
	exit
fi

if [[ "$type" != "nucl" ]] && [[ "$type" != "prot" ]]
then
	echo "Molecular type (-d option) must be nucl or prot."
	exit
fi

if [[ $name ]]
then
	taxid=$(sqlite3 "$names_nodes_db" "select taxid from names where name=\"$name\";")

	if [[ $taxid == "" ]]
	then
		echo "$name not found - returning similar hits"
	
		sqlite3 "$names_nodes_db" "select * from names where name LIKE \"%$name%\";" | while read line; do
			echo "$line"
		done
		exit
	fi
elif [[ $taxid ]]
then
	name=$(sqlite3 "$names_nodes_db" "select name from names where taxid=\"$taxid\";")
else
	echo "You must supply either a name or a taxid."
	exit
fi
rank=$(sqlite3 "$names_nodes_db" "select rank from nodes where taxid=\"$taxid\";")
name_no_spaces=${name// /_}
outputfile="${name_no_spaces}_${taxid}_${type}.gb"

if [[ $PIPELINE ]]
then
	if [[ ! $direct_links ]]
	then
		taxidfile="${name_no_spaces}_${taxid}.taxid"
		#Add parent so direct hits can be found
		echo $taxid > $taxidfile
		#Now, find all child taxid
		NCBI_parenttaxid_to_childtaxid.sh -t $taxid >> $taxidfile
		NCBI_taxid_to_gb.pl $gb -d "$type" -i $taxidfile -q $taxonomy_folder
	else
		NCBI_taxid_to_gb.pl $gb -d "$type" -t $taxid -q $taxonomy_folder
	fi
else
	echo "name: $name"
	echo "rank: $rank"
	echo "taxid: $taxid"
	echo "_________________________"
	echo "gb list: $outputfile"
	if [[ ! $direct_links ]]
	then
		taxidfile="${name_no_spaces}_${taxid}.taxid"
		echo "taxid list: $taxidfile"
		echo "_________________________"
		echo
		echo "Finding child taxid..."
		#Add parent so direct hits can be found
		echo $taxid > $taxidfile
		#Now, find all child taxid
		NCBI_parenttaxid_to_childtaxid.sh -t $taxid -q $taxonomy_folder >> $taxidfile
		echo "Finding gb..."
		NCBI_taxid_to_gb.pl $gb -d "$type" -i $taxidfile -q $taxonomy_folder > "$outputfile"
	else
		echo "_________________________"
		NCBI_taxid_to_gb.pl $gb -d "$type" -t $taxid -q $taxonomy_folder > "$outputfile"
	fi
fi
