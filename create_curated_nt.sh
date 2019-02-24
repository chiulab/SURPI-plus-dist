#!/bin/bash
#
#	create_curated_nt.sh
#
#	This program will create a FASTA file to be indexed with SNAP.

scriptname=${0##*/}
bold=$(tput bold)
normal=$(tput sgr0)

#input: nt database from NCBI
#required: NCBI taxonomy database

# Currently, NCBI taxonomy has the following groups at the top level of the hierarchy:
# Archaea
# Bacteria
# Eukaryota
# Viroids
# Viruses
# Other
# Unclassified

# This script will remove the taxid corresponding to the names in the names_list array
# Using this taxid list, it then looks up all the Genbank identifiers contained within the taxid & places them into $gb_to_remove
# Finally, it removes all the Genbank identifier from the FASTA file given (should be an nt file)

optspec=":ghi:q:"
while getopts "$optspec" option; do
	case "${option}" in
		g) GI=1;;
		h) HELP=1;;
		i) nt_FASTA=${OPTARG};;
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

This program will create a FASTA file to be indexed with SNAP.
The SNAP database is intended to be used as the identifying database
within the SURPI pipeline.

${bold}Command Line Switches:${normal}

	-h	Show this help & ignore all other switches

	-g	Base databases on GI numbers (default: use accession)

	-i	Specify location of nt file (in FASTA format) to use as input (this is the file to be curated)

	-q	folder containing taxonomy databases

		This folder should contain taxonomy databases that are synchronized with the nt file being curated (-i option).

		This folder should contain the 3 SQLite files created by the script "create_taxonomy_db.sh"
			(acc|gi)_taxid_nucl.db - nucleotide db of (acc|gi)/taxonid
			(acc|gi)_taxid_prot.db - protein db of (acc|gi)/taxonid
			names_nodes_scientific.db - db of taxonid/taxonomy

${bold}Usage:${normal}
	create_curated_nt.sh -i nt -q /reference/taxonomy

USAGE
	exit
fi
START_creation=$(date +%s)

if [[ $taxonomy_folder ]]
then
	names_nodes_db="$taxonomy_folder/names_nodes_scientific.db"
else
	echo "You need to supply the taxonomy folder location using -q."
	exit
fi

if [[ $nt_FASTA ]]
then
	output_FASTA=$(basename ${nt_FASTA}_curated.fa)
	sequences_removed=$(basename ${nt_FASTA}_removed.fa)
else
	echo "You need to supply the nt FASTA file location using -i."
	exit
fi

name_to_taxid() {
	name=$1
	sqlite3 "$names_nodes_db" "select * from names where name LIKE \"%$name%\";" | while read line; do
		echo "$line"
	done
}
taxid_to_remove="taxid_to_remove.taxid"
gb_to_remove="gb_to_remove.gb"

> $taxid_to_remove
> $gb_to_remove

declare -a names_list=(	"other sequences" \
						"uncultured" \
						"artificial" \
						"environmental" \
						"vector" \
						"plasmid" \
						"unclassified" \
						"unclassified sequences" \
						"artificial" \
						"expression construct" \
						"synthetic construct" \
						"synthetic organisms" \
						"synthetic viruses" \
						"synthetic Mycoplasma mycoides JCVI-syn1.0" \
						"Synthetic conjugative molecular parasite pX1.0" \
						"synthetic metagenome" \
						"synthetic Enterobacteria phage phiX174.1f" \
						"synthetic phages" \
						 )

for name in "${names_list[@]}"
do
	name_to_taxid "$name" >> "${taxid_to_remove}.full"
	awk -F\| '{print $1}' "${taxid_to_remove}.full" >> "$taxid_to_remove"
done
sort -nu "$taxid_to_remove" > "$taxid_to_remove.uniq"
if [[ ${GI} -eq 1 ]]; then
	NCBI_taxid_to_gb.pl -g -i "$taxid_to_remove.uniq" -d nucl -q "$taxonomy_folder" >> "$gb_to_remove"
else
	NCBI_taxid_to_gb.pl -i "$taxid_to_remove.uniq" -d nucl -q "$taxonomy_folder" >> "$gb_to_remove"
fi

taxid_count=$(wc -l "$taxid_to_remove.uniq")
gb_count=$(wc -l "$gb_to_remove")

echo -e "$(date)\t$scriptname\tTaxonomic Restriction"
echo -e "$(date)\t$scriptname\ttaxid removed: $taxid_count"
echo -e "$(date)\t$scriptname\tgb removed: $gb_count"

END_gb_list_creation=$(date +%s)
diff_gb_list_creation=$(( END_gb_list_creation - START_creation ))
echo -e "$(date)\t$scriptname\tTaxonomic gb list creation took $diff_gb_list_creation seconds"

# for GI want bare number and description
# accession-only fastas already have format
if [[ ${GI} -eq 1 ]]; then
	START_header_cleanup=$(date +%s)
	# clean up headers to remove all except for first gi and description
	# exclude accessions, etc
	# >gi|174432|gb|K00218.1|ECOTRI2 E.coli Ile-tRNA-2
	# becomes >gi|174432| E.coli Ile-tRNA-2
	# need desciption for bolt lookup database
	echo -e "$(date)\t$scriptname\tShrinking headers..."
	sed "s/.*//" "$nt_FASTA" | sed "s/^\(>gi|[0-9]\+|\)\S*\s\+/\1 /" > "${nt_FASTA}.reducedheaders"
	END_header_cleanup=$(date +%s)
	diff_header_cleanup=$(( END_header_cleanup - START_header_cleanup ))
	echo -e "$(date)\t$scriptname\tHeader cleanup took $diff_header_cleanup seconds"
fi

#Now, do removal & create new FASTA file
#	$nt_FASTA: input FASTA
#	$gb_to_remove: gb list to remove
#	$output_FASTA = ($nt_FASTA - $gb_to_remove)
#	$sequences_removed = (FASTA of $gb_to_remove)
#	i.e. $nt_FASTA = ($output_FASTA + $sequences_removed)
START_tax_restriction=$(date +%s)

if [[ ${GI} -eq 1 ]]; then
	remove_gi_from_fasta.py "${nt_FASTA}.reducedheaders" "$gb_to_remove" "$output_FASTA" "$sequences_removed"
else
	remove_acc_from_fasta.py "${nt_FASTA}" "$gb_to_remove" "$output_FASTA" "$sequences_removed"
fi

END_tax_restriction=$(date +%s)
diff_tax_restriction=$(( END_tax_restriction - START_creation ))
echo -e "$(date)\t$scriptname\tTaxonomic Restriction took $diff_tax_restriction seconds"

