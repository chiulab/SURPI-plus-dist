#!/bin/bash
#
#	create_taxonomy_db.sh
#
# 	This script creates the SQLite taxonomy database using NCBI downloadable files
#
#	Chiu Laboratory
#	University of California, San Francisco
#	January, 2014
#
# Copyright (C) 2014 Scot Federman - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.

scriptname=${0##*/}

# FIXME remove hard-coding; how to specify?
tag_db_file="/usr/local/bin/surpi-dev/tagging_list_5.txt"

while getopts ":d:ghm:" option; do
	case "${option}" in
		d) db_directory=${OPTARG};;
		g) GI=1;;
		h) HELP=1;;
		m) MERGED=${OPTARG};;
		:)	echo "Option -$OPTARG requires an argument." >&2
			exit 1
      		;;
	esac
done

if [[ ${HELP} -eq 1  ||  $# -lt 1 ]]
then
	cat <<USAGE

${bold}$scriptname${normal}

This script will create the taxonomy SQLite database using NCBI downloadable files.

${bold}Command Line Switches:${normal}

	-h	Show this help

	-g	Base databases on GI numbers (default: use accession)

	-d	Specify directory containing NCBI data

	-m	Specify whether to adjust taxid using merged.dmp [T (default)/F]
			This step will use the merged.dmp file (from NCBI taxonomy). This file lists old taxids and
		their new taxid.

${bold}Usage:${normal}

USAGE
	exit
fi

if [[ -z $MERGED ]]
then
	MERGED="T"
elif [[ $MERGED != "T" && $MERGED != "F" ]]
then
	echo "-m option must be T or F."
	exit
fi

# New lookup files have 4 columns
# accession accession.version taxid gi

# legacy GI
if [[ ${GI} -eq 1 ]]; then
	if [ -f "$db_directory/taxdump.tar.gz" ] && [ -f "$db_directory/gi_taxid_nucl.dmp.gz" ] && [ -f "$db_directory/gi_taxid_prot.dmp.gz" ]; then
		echo -e "$(date)\t$scriptname\tTaxonomy files found."
	else
		echo -e "$(date)\t$scriptname\tNecessary files not found. Exiting..."
		exit
	fi

	echo -e "$(date)\t$scriptname\tUnzipping downloads..."
	tar xfz "$db_directory/taxdump.tar.gz"
	pigz -dc -k "$db_directory/gi_taxid_nucl.dmp.gz" > gi_taxid_nucl.dmp
	pigz -dc -k "$db_directory/gi_taxid_prot.dmp.gz" > gi_taxid_prot.dmp

	# the below grep "fixes" the issue whereby aliases, mispellings, and other alternate names are returned.
	# We could simply look for a name that is a "scientific name",
	# but this shrinks the db a bit, speeding up lookups, and removes data we do not need at this time.
	echo -e "$(date)\t$scriptname\tRetaining scientific names..."
	grep "scientific name" names.dmp > names_scientificname.dmp

	echo -e "$(date)\t$scriptname\tStarting creation of taxonomy SQLite databases..."
	if [[ $MERGED == "T" ]]
	then
		create_taxonomy_db.py --gi --merge
	else
		create_taxonomy_db.py --gi
	fi
else
	# ACCESSIONS
	if [ -f "$db_directory/taxdump.tar.gz" ] && [ -f "$db_directory/nucl_gb.accession2taxid.gz" ] && [ -f "$db_directory/prot.accession2taxid.gz" ]; then
		echo -e "$(date)\t$scriptname\tTaxonomy files found."
	else
		echo -e "$(date)\t$scriptname\tNecessary files not found. Exiting..."
		exit
	fi

	echo -e "$(date)\t$scriptname\tUnzipping downloads..."
	tar xfz "$db_directory/taxdump.tar.gz"
	pigz -dc -k "$db_directory/nucl_gb.accession2taxid.gz" > nucl_gb.accession2taxid
	pigz -dc -k "$db_directory/prot.accession2taxid.gz" > prot.accession2taxid

	# the below grep "fixes" the issue whereby aliases, mispellings, and other alternate names are returned.
	# We could simply look for a name that is a "scientific name",
	# but this shrinks the db a bit, speeding up lookups, and removes data we do not need at this time.
	echo -e "$(date)\t$scriptname\tRetaining scientific names..."
	grep "scientific name" names.dmp > names_scientificname.dmp

	echo -e "$(date)\t$scriptname\tStarting creation of taxonomy SQLite databases..."
	if [[ $MERGED == "T" ]]
	then
		create_taxonomy_db.py --merge
	else
		create_taxonomy_db.py
	fi
fi

# Add tags
# Above makes a big mess of files all in current dir so the tax db file
# here is the correct path, i.e., current dir
tax_db_file="names_nodes_scientific.db"
tagTaxonomy.py load --tagfile $tag_db_file --taxdb $tax_db_file

echo -e "$(date)\t$scriptname\tCompleted creation of taxonomy SQLite databases."

rm -f *.dmp
rm -f gc.prt
rm -f readme.txt
