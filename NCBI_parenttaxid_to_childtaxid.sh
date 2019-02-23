#!/bin/bash
#
#	NCBI_parenttaxid_to_childtaxid.sh
#
#	This program will take a taxid as input, and return all the child taxid
#	Chiu Laboratory
#	University of California, San Francisco
#
# Copyright (C) 2014 Scot Federman - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.

scriptname=${0##*/}
bold=$(tput bold)
normal=$(tput sgr0)
optspec=":t:hq:"

while getopts "$optspec" option; do
	case "${option}" in
		h) HELP=1;;
		t) taxid=${OPTARG};;
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

This program will return a list of child taxid for a given NCBI taxid.

${bold}Command Line Switches:${normal}

	-h	Show this help & ignore all other switches

	-t	Specify taxid	

	-q	folder containing taxonomy databases
		This folder should contain the 3 SQLite files created by the script "create_taxonomy_db.sh"
			(acc|gi)_taxid_nucl.db - nucleotide db of (acc|gi)/taxonid
			(acc|gi)_taxid_prot.db - protein db of (acc|gi)/taxonid
			names_nodes_scientific.db - db of taxonid/taxonomy

${bold}Usage:${normal}

	Extract list of child taxid for taxid 28384 "other sequences"
		$scriptname -t 28384

	Extract list of child taxid for taxid 10239 "Viruses"
		$scriptname -t 10239

USAGE
	exit
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


parent_to_children() {
	children=$(sqlite3 "$names_nodes_db" "select taxid from nodes where parent_taxid=$1")
	if [[ ! $children ]]
	then
		return
	fi
	echo "$children"
	for child in $children
	do
		parent_to_children $child
	done
}

parent_to_children $taxid
