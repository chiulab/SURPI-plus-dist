#!/bin/bash
#
#	SURPI.sh
#
#	This is the main driver script for the SURPI pipeline.
#	Chiu Laboratory
#	University of California, San Francisco
#
#
# Copyright (C) 2014 Samia N Naccache, Scot Federman, and Charles Y Chiu - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.
#
SURPI_version="1.0.67"

bold=$(tput bold)
normal=$(tput sgr0)
green='\e[0;32m'
red='\e[0;31m'
endColor='\e[0m'

host=$(hostname)
reference_directory="/reference" # top level directory containing all ref data
scriptname=${0##*/}

optspec=":f:hr:vz:"
while getopts "$optspec" option; do
	case "${option}" in
		f) config_file=${OPTARG};; # get parameters from config file if specified
		h) HELP=1;;
		r) reference_directory=${OPTARG};;
		v) VERIFICATION=1;;
		z)	create_config_file=${OPTARG}
			configprefix=${create_config_file%.fastq}
			;;
# 		c)	config_file=${OPTARG}
# 			configprefix=${create_config_file%.fastq}
# 			;;
		:)	echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

if [[ $HELP -eq 1  ||  $# -lt 1 ]]
then
	cat <<USAGE

${bold}SURPI version ${SURPI_version}${normal}

This program will run the SURPI pipeline with the parameters supplied by the config file.

${bold}Command Line Switches:${normal}

	-h	Show this help & ignore all other switches

	-r	Specify reference directory [optional - default: "$reference_directory"]

	-f	Specify config file

		This switch is used to initiate a SURPI run using a specified config file. Verification (see -v switch) will occur at the beginning of the run.
		The pipeline will cease if SURPI fails to find a software dependency or necessary reference data.

	-v	Verification mode

		When using verification mode, SURPI will verify necessary dependencies, but will
		stop after verification. This same verification is also done
		before each SURPI run.

			• software dependencies
				SURPI will check for the presence of all software dependencies.
			• reference data specified in config file
				SURPI does a cursory check for the presence of reference data. This check is
				not a comprehensive test of the reference data.
			• taxonomy lookup functionality
				SURPI verifies the functionality of the taxonomy lookup.
			• FASTQ file (if requested in config file)
				SURPI uses fastQValidator to check the integrity of the FASTQ file.

	-z	Create default config file and go file. [optional] (specify fastq filename)
		This option will create a standard .config file, and go file.

${bold}Usage:${normal}

	Create default config and go file.
		$scriptname -z test.fastq

	Run SURPI pipeline in verification mode:
		$scriptname -f config -v

	Run SURPI pipeline with the config file:
		$scriptname -f config

USAGE
	exit
fi

if [[ $create_config_file ]]
then
#------------------------------------------------------------------------------------------------
(
	cat <<EOF
# This is the config file used by SURPI. It contains mandatory parameters,
# optional parameters, and server related constants.
# Do not change the config_file_version - it is auto-generated.
# 	and used to ensure that the config file used matches the version of the SURPI pipeline run.
config_file_version="$SURPI_version"

##########################
#  Input file
##########################

#To create this file, concatenate the entirety of a sequencing run into one FASTQ file.
#SURPI currently does not have paired-end functionality, we routinely concatenate Read 1 and Read 2 into the unified input file.
#For SURPI to provide proper readcount statistics, all read headers in a single SURPI input dataset should share a
#common 3 letter string (eg: M00, HWI, HIS, SCS, SRR for example). SURPI currently selects the string from the first and last reads only.
inputfile="$create_config_file"

#input filetype. [FASTA/FASTQ]
inputtype="FASTQ"

#FASTQ quality score type: [Sanger/Illumina]
#Sanger = Sanger score (ASCII-33)
#Illumina = Illumina score (ASCII-64)
#Counterintuitively, the Sanger quality format is likely the method your data is encoded in if you are generating data on an Illumina machine after early 2011.
#Selecting Illumina quality on Sanger data will likely lead to improper preprocessing, resulting in preprocessed files of 0 length.
quality="Sanger"

#Adapter set used. [Truseq/Nextera/NexSolB/NexSolTruseq]
#Truseq = trims truseq adaptors
#Nextera = trims Nextera adaptors
adapter_set="NexSolTruseq"

#Verify FASTQ quality
#	0 = skip validation
#	1 [default] = run validation, don't check for unique names, quit on failure
#	2 = run validation, check for unique names, quit on failure (helpful with newer MiSeq output that has same name for read1 and read2 due to spacing)
#	3 = run validation, check for unique names, do not quit on failure
VERIFY_FASTQ=1

# SampleSheet filename. By default is SampleSheet.csv, but could be different. Not used in SURPI pipeline, but it can be transferred to SURPI run folder, 
#	and if so, SURPI.sh will move it to the output folder to be used for SURPIviz downstream.
illumina_samplesheet="SampleSheet.csv"

##########################
# Run Mode
##########################

bowtie_subtraction="Y"

#Below options are to skip specific steps.

#Uncomment preprocess parameter to skip preprocessing
#(useful for large data sets that have already undergone preprocessing step)
# If skipping preprocessing, be sure these files exist in the working directory.
# .cutadapt.fastq
# .preprocessed.fastq
#skip_preprocess="Y"

#skip_host_subtraction="Y"

#exit_after_preprocessing="Y"
#exit_after_host_subtraction="Y"
#exit_after_classification="Y"

#This will turn on debug mode, which is used to keep intermediate files for troubleshooting purposes.
#	• retains SNAP SAM files generated during classification
#SURPI_DEBUG="Y"

##########################
# Preprocessing
##########################

#length_cutoff: after quality and adaptor trimming, any sequence with length smaller than length_cutoff will be discarded
length_cutoff="100"

#Cropping quality trimmed reads prior to SNAP alignment
#snapt_nt = Where to start crop
#crop_length = how long to crop
start_nt=10
crop_length=100

#quality cutoff ( -q switch in cutadapt )
quality_cutoff=18


##########################
# SNAP
##########################

#SNAP edit distance for Computational Subtraction of host genome
#see Section 3.1.2 MaxDist description: http://snap.cs.berkeley.edu/downloads/snap-1.0beta-manual.pdf
d_human=18

#SNAP edit distance for alignment to NCBI nt DB [validated only at: d=12]
d_NT_alignment=16

#SNAP edit distance for cleanup
d_cleanup=18

#SNAP omax. See SNAP documentation for details:
#omax and om are used during the alignment phas of SURPI
snap_omax=1000

#SNAP om. See SNAP documentation for details:
snap_om=0

#SNAP edit distance (secondary cutoff) currently used for Bacteria/Fungi/Parasite
d_NT_secondary_cutoff=1


##########################
# Filtering
##########################

#e value for BLASTn used in filtering scripts
eBLASTn_filter="1e-8"


##########################
# Reference Data
##########################

# Base directory for all reference data.
reference_directory="$reference_directory"

# SNAP-indexed database of host genome (for subtraction phase)
# SURPI will subtract all SNAP databases found in this directory from the input sequence
# Useful if you want to subtract multiple genomes (without combining SNAP databases)
# or, if you need to split a db if it is larger than available RAM.
SNAP_subtraction_folder="\$reference_directory/snap_hg38_primate"

#Bowtie2 indexed database
BOWTIE2_FOLDER="\$reference_directory/bowtie2_hg38/"

# directory for SNAP-indexed databases of NCBI NT (for mapping phase in comprehensive mode)
# directory must ONLY contain snap indexed databases
SNAP_COMPREHENSIVE_db_dir="\$reference_directory/COMP_SNAP_no_primate"

#Taxonomy Reference data directory
#This folder should contain the 3 SQLite files created by the script "create_taxonomy_db.sh"
#gi_taxid_nucl.db - nucleotide db of gi/taxonid
#gi_taxid_prot.db - protein db of gi/taxonid
#names_nodes_scientific.db - db of taxonid/taxonomy
taxonomy_db_directory="\$reference_directory/taxonomy"

#SNAP Cleanup databases (indexed with SNAP 1.0)
bacteria_cleanup_db="\$reference_directory/RiboClean_SNAP1.0/snap_bacteria.fa_s16"
eukaryote_cleanup_db="\$reference_directory/RiboClean_SNAP1.0/snap_eukaryote.fa_s16"
vector_cleanup_db="\$reference_directory/Vector_SNAP/snap_UniVec"

#BLAST folder containing nt database used in filtering.
BLAST_folder="\$reference_directory/BLASTDB/"

#Specify location of Excel template used for counttables
excel_template="\$SCIF_APPROOT/SURPI/etc/SURPI_summary_template.xlsx"

##########################
# Server related values
##########################

#Set this parameter if you are using an SSD instead of a spinning disk. It will set several parameters within
#the pipeline to help optimize speed.
SSD=0

#Number of cores to use. Will use all cores on machine if unspecified.
#Uncomment the parameter to set explicitly.
#cores=64

#specify a location for storage of temporary files.
#Space needed may be up to 10x the size of the input file.
#This folder will not be created by SURPI, so be sure it already exists with proper permissions.
temporary_files_directory="/tmp/"


EOF
) > $configprefix.config
#------------------------------------------------------------------------------------------------
echo "$configprefix.config generated. Please edit it to contain the proper parameters for your analysis."
echo
exit
fi

if [[ -r "$config_file" ]]
then
	source "$config_file"
	#verify that config file version matches SURPI version
	if [ "$config_file_version" != "$SURPI_version" ]
	then
		echo "The config file $config_file was created with SURPI $config_file_version."
		echo "The current version of SURPI running is $SURPI_version."
		echo "Please generate a new config file with SURPI $SURPI_version in order to run SURPI."

		exit 65
	fi
else
	echo "The config file specified: $config_file is not present."
	exit 65
fi

#check that $inputfile is a FASTQ file, and has a FASTQ suffix.
# convert from FASTA if necessary, add FASTQ suffix if necessary.
if [ "$inputtype" = "FASTQ" ]
then
	if [ ${inputfile##*.} != "fastq" ]
	then
		ln -s "$inputfile" "$inputfile.fastq"
		FASTQ_file="$inputfile.fastq"
	else
		FASTQ_file="$inputfile"
	fi
elif [ "$inputtype" = "FASTA" ]
then
	echo "Converting $inputfile to FASTQ format..."
	FASTQ_file="$inputfile.fastq"
	fasta_to_fastq "$inputfile" > "$FASTQ_file"
fi

#set cores. if none specified, use all cores present on machine
if [ ! $cores ]
then
	total_cores=$(grep processor /proc/cpuinfo | wc -l)
	cores=${cores:-$total_cores}
fi

#these 2 parameters are for cropping prior to snap in the preprocessing stage
if [ ! $start_nt ]
then
	echo "${bold}start_nt${normal} was not specified."
	exit 65
fi

if [ ! $crop_length ]
then
	echo "${bold}crop_length${normal} was not specified."
	exit 65
fi

if [ "$adapter_set" != "Truseq" -a "$adapter_set" != "Nextera" -a "$adapter_set" != "NexSolB" -a "$adapter_set" != "NexSolTruseq" ]
then
	echo "${bold}$adapter_set${normal} is not a valid adapter_set - must be Truseq, Nextera, NexSolTruseq, or NexSolB."
	exit 65
fi

if [ "$quality" != "Sanger" -a "$quality" != "Illumina" ]
then
	echo "${bold}$quality${normal} is not a valid quality - must be Sanger or Illumina."
	exit 65
fi
if [ $quality = "Sanger" ]
then
	quality="S"
else
	quality="I"
fi

if [ ! $d_human ]
then
	echo "${bold}d_human${normal} was not specified."
	exit 65

fi

if [ ! $length_cutoff ]
then
	echo "${bold}length_cutoff${normal} was not specified."
	exit 65
fi


nopathf=${FASTQ_file##*/} # remove the path to file
basef=${nopathf%.fastq}
export SURPI_basef=${nopathf%.fastq}

#verify that all software dependencies are properly installed
declare -a dependency_list=("gt" "seqtk" "fastq" "fqextract" "cutadapt" "prinseq-lite.pl" "snap-dev" "fastQValidator" "classify" "readcount" "counttable" "bowtie2" "bowtie2-inspect")
echo "-----------------------------------------------------------------------------------------"
echo "DEPENDENCY VERIFICATION"
echo "-----------------------------------------------------------------------------------------"
for command in "${dependency_list[@]}"
do
        if hash $command 2>/dev/null; then
                echo -e "$command: ${green}OK${endColor}"
        else
                echo
                echo -e "$command: ${red}BAD${endColor}"
                echo "$command does not appear to be installed properly."
                echo "Please verify your SURPI installation and \$PATH, then restart the pipeline"
                echo
				dependency_check="FAIL"
        fi
done
echo "-----------------------------------------------------------------------------------------"
echo "SOFTWARE VERSION INFORMATION"
echo "-----------------------------------------------------------------------------------------"
seqtk_version=$(seqtk 2>&1 | head -3 | tail -1 | awk '{print $2}')
cutadapt_version=$(cutadapt --version)
prinseqlite_version=$(prinseq-lite.pl --version 2>&1 | awk '{print $2}')
snap_dev_version=$(snap-dev 2>&1 | grep version | awk '{print $5}')
bowtie2_version=$(bowtie2 --version | head -1 | awk '{print $3}')

#SURPIviz versions
readcount_version=$(readcount -version | awk '{print $2}')
counttable_version=$(counttable -version | awk '{print $2}')
classify_version=$(classify -version | awk '{print $2}')
summarize_version=$(summarizeReadCounts.py --version | awk '{print $2}')

echo -e "SURPI version: $SURPI_version"
echo -e "config file version: $config_file_version"
echo -e "seqtk: $seqtk_version"
echo -e "cutadapt: $cutadapt_version"
echo -e "prinseq-lite: $prinseqlite_version"
echo -e "snap-dev: $snap_dev_version"
echo -e "bowtie2: $bowtie2_version"
echo "------------------------"
echo -e "SURPIviz"
echo "------------------------"
echo -e "classify: $classify_version"
echo -e "readcount: $readcount_version"
echo -e "counttable: $counttable_version"
echo -e "summarizeReadCounts.py: $summarize_version"

echo "-----------------------------------------------------------------------------------------"
echo "REFERENCE DATA VERIFICATION"
echo "-----------------------------------------------------------------------------------------"

echo -e "SNAP Subtraction db"
for f in $SNAP_subtraction_folder/*
do
	if [ -f $f/Genome ]
	then
		echo -e "\t$f: ${green}OK${endColor}"
	else
		echo -e "\t$f: ${red}BAD${endColor}"
		reference_check="FAIL"
	fi
done

echo -e "SNAP Comprehensive Mode database"
for f in $SNAP_COMPREHENSIVE_db_dir/*
do
	if [ -f $f/Genome ]
	then
		echo -e "\t$f: ${green}OK${endColor}"
	else
		echo -e "\t$f: ${red}BAD${endColor}"
		reference_check="FAIL"
	fi
done

echo -e "Bowtie2 Subtraction database"
for db_path in $BOWTIE2_FOLDER/*
do
	db_name=$(basename "$db_path")
	# checks if database is a 2.0 compatible bowtie2 database (by having the line: 2.0-compatible	1)
	result=$(bowtie2-inspect -s "$db_path/$db_name" | head | grep "2.0-compatible" | awk '{print $2}')
	if [ "$result" -eq 1 ]
	then
		echo -e "\t$db_path: ${green}OK${endColor}"
	else
		echo -e "\t$db_path: ${red}BAD${endColor}"
		if [ "$bowtie_subtraction" = "Y" ]
		then
			reference_check="FAIL"
		fi
	fi
done

echo -e "taxonomy database"
result=$( sqlite3 -line "$taxonomy_db_directory/names_nodes_scientific.db" 'select name from names where taxid = 1;' )
if [ "$result" = " name = root" ]
then
	echo -e "taxonomy: ${green}OK${endColor}"
else
	echo -e "taxonomy: ${red}BAD${endColor}"
	echo -e "${red}taxonomy appears to be malfunctioning. Please check logs and config file to verify proper taxonomy functionality.${endColor}"
	reference_check="FAIL"
fi

if [[ ("$dependency_check" = "FAIL" || "$reference_check" = "FAIL") ]]
then
	echo -e "${red}There is an issue with one of the dependencies or reference databases above.${endColor}"
	exit 65
else
	echo -e "${green}All necessary dependencies and reference data pass.${endColor}"
fi

length=$( expr length $( head -n2 "$FASTQ_file" | tail -1 ) ) # get length of 1st sequence in FASTQ file
contigcutoff=$(perl -le "print int(1.75 * $length)")

# This code is checking that the top header is equal to the bottom header.
headerid_top=$(head -1 "$basef.fastq" | cut -c1-4)
headerid_bottom=$(tail -4 "$basef.fastq" | cut -c1-4 | head -n 1)
echo "-----------------------------------------------------------------------------------------"
echo "INPUT FILE VERIFICATION"
echo "-----------------------------------------------------------------------------------------"

if [[ "$headerid_top" != "$headerid_bottom" ]]
then
	echo -e "${red}$(date)\t$scriptname\tSURPI aborted due to non-unique header id.${endColor}"
	echo -e "${red}$(date)\t$scriptname\tHeaderid_top: $headerid_top.${endColor}"
	echo -e "${red}$(date)\t$scriptname\tHeaderid_bottom: $headerid_bottom.${endColor}"

	exit 65
else
	echo -e "${green}$(date)\t$scriptname\theaderid_top matches headerid_bottom ($headerid_top).${endColor}"	
fi

if [ "$VERIFY_FASTQ" = 1 ]
then
	fastQValidator --file "$FASTQ_file" --printBaseComp --avgQual --disableSeqIDCheck > "quality.$basef.log" &
	if [ $? -eq 0 ]
	then
		echo -e "${green}$FASTQ_file appears to be a valid FASTQ file. Check the quality.$basef.log file for details.${endColor}"
	else
		echo -e "${red}$FASTQ_file appears to be a invalid FASTQ file. Check the quality.$basef.log file for details.${endColor}"
		echo -e "${red}You can bypass the quality check by not using the -v switch.${endColor}"
		exit 65
	fi
elif [ "$VERIFY_FASTQ" = 2 ]
then
	fastQValidator --file "$FASTQ_file" --printBaseComp --avgQual > "quality.$basef.log" &
	if [ $? -eq 0 ]
	then
		echo -e "${green}$FASTQ_file appears to be a valid FASTQ file. Check the quality.$basef.log file for details.${endColor}"
	else
		echo -e "${red}$FASTQ_file appears to be a invalid FASTQ file. Check the quality.$basef.log file for details.${endColor}"
		echo -e "${red}You can bypass the quality check by not using the -v switch.${endColor}"

		exit 65
	fi
elif [ "$VERIFY_FASTQ" = 3 ]
then
	fastQValidator --file "$FASTQ_file" --printBaseComp --avgQual > "quality.$basef.log" &
fi
if [[ "$VERIFICATION" -eq 1 ]] #stop pipeline if using verification mode
then
	exit
fi
echo "-----------------------------------------------------------------------------------------"
echo "SERVER VERIFICATION"
echo "-----------------------------------------------------------------------------------------"
#set TMPDIR for programs to use.
export TMPDIR="$temporary_files_directory"
export SSD
if [[ "$SURPI_DEBUG" = "Y" ]]
then
	export SURPI_DEBUG
fi

if [ -w "$TMPDIR" ]
then
	echo -e "${green}SURPI can successfully write to $TMPDIR.${endColor}"
else
	echo -e "${red}SURPI cannot successfully write to $TMPDIR.${endColor}"
	echo -e "${red}Please set the parameter: ${bold}$TMPDIR${normal}${red} located in $basef.config${endColor}"
	echo -e "${red}to a directory that SURPI can write to.${endColor}"

	exit 65
fi


#
##
### Send alert that pipeline is starting
##
#

echo "-----------------------------------------------------------------------------------------"
echo "INPUT PARAMETERS"
echo "-----------------------------------------------------------------------------------------"
echo "Command Line Usage: $scriptname $@"
echo "SURPI version: $SURPI_version"
echo "SURPI_DEBUG: $SURPI_DEBUG"
echo "config_file: $config_file"
echo "config file version: $config_file_version"
echo "Server: $host"
echo "Working directory: $( pwd )"
echo "inputfile: $inputfile"
echo "inputtype: $inputtype"
echo "FASTQ_file: $FASTQ_file"
echo "cores used: $cores"

echo "bowtie_subtraction: $bowtie_subtraction"
echo "skip_preprocess: $skip_preprocess"
echo "skip_host_subtraction: $skip_host_subtraction"
echo "exit_after_preprocessing: $exit_after_preprocessing"
echo "exit_after_host_subtraction: $exit_after_host_subtraction"
echo "exit_after_classification: $exit_after_classification"


echo "Raw Read quality: $quality"
echo "Quality cutoff: $quality_cutoff"
echo "Read length_cutoff for preprocessing under which reads are thrown away: $length_cutoff"

echo "temporary files location: $TMPDIR"

echo "SNAP_db_directory housing the reference databases for Subtraction: $SNAP_subtraction_folder"
echo "Bowtie2_db_directory housing the reference databases for Subtraction: $BOWTIE2_FOLDER"

echo "SNAP_db_directory housing the reference databases for Comprehensive Mode: $SNAP_COMPREHENSIVE_db_dir"
echo "SNAP edit distance for SNAP to Human: d_human: $d_human"
echo "SNAP edit distance for SNAP to NT: d_NT_alignment: $d_NT_alignment"

echo "taxonomy database directory: $taxonomy_db_directory"
echo "adapter_set: $adapter_set"

echo "Raw Read length: $length"

echo "start_nt: $start_nt"
echo "crop_length: $crop_length"

echo "-----------------------------------------------------------------------------------------"
###########################################################
echo -e "$(date)\t$scriptname\t########## STARTING SURPI PIPELINE ##########"
START_PIPELINE=$(date +%s)
echo -e "$(date)\t$scriptname\tFound file $FASTQ_file"
echo -e "$(date)\t$scriptname\tAfter removing path: $nopathf"

#Adjust SampleSheet.csv name if necessary
if [ -e "$illumina_samplesheet" ]; then mv "$illumina_samplesheet" "$basef.$illumina_samplesheet"; fi

############ PREPROCESSING ##################
preprocess_input="$basef.fastq"

if [ "$skip_preprocess" != "Y" ]
then
	echo -e "$(date)\t$scriptname\t############### PREPROCESSING ###############"
	echo -e "$(date)\t$scriptname\tStarting: preprocessing using $cores cores "
	START_PREPROC=$(date +%s)
	echo -e "$(date)\t$scriptname\tParameters: preprocess_ncores.sh $preprocess_input $quality N $length_cutoff $cores N $adapter_set $start_nt $crop_length $quality_cutoff $basef > $basef.preprocess.log 2> $basef.preprocess.err"
	run_uniq="N"
	keep_short_reads="N"
	preprocess_ncores.sh "$preprocess_input" "$quality" "$run_uniq" "$length_cutoff" "$cores" "$keep_short_reads" "$adapter_set" "$start_nt" "$crop_length" "$quality_cutoff" "$basef" > "$basef.preprocess.log" 2> "$basef.preprocess.err"
	echo -e "$(date)\t$scriptname\tDone: preprocessing "
	END_PREPROC=$(date +%s)
	diff_PREPROC=$(( END_PREPROC - START_PREPROC ))
	echo -e "$(date)\t$scriptname\tPreprocessing took $diff_PREPROC seconds" | tee "timing.$basef.log"
fi

preprocessed_fastq="$basef.preprocessed.fastq"
cutadapted_fastq="$basef.cutadapt.fastq"

# verify preprocessing step
if [ ! -s "$cutadapted_fastq" ] || [ ! -s "$preprocessed_fastq" ]
then
	echo -e "$(date)\t$scriptname\t${red}Preprocessing appears to have failed. One of the following files does not exist, or is of 0 size:${endColor}"
	echo "$basef.cutadapt.fastq"
	echo "$basef.preprocessed.fastq"

	exit
fi
if [[ "$exit_after_preprocessing" == "Y" ]]
then
	echo -e "$(date)\t$scriptname\texiting - exit_after_preprocessing = $exit_after_preprocessing." | tee -a "timing.$basef.log"
	exit
fi
############# BEGIN SNAP PIPELINE #################
freemem=$(free -g | awk '{print $4}' | head -n 2 | tail -1)
echo -e "$(date)\t$scriptname\tThere is $freemem GB available free memory..."

############# HOST SUBTRACTION #################

snap_subtraction_input="$preprocessed_fastq"
snap_subtraction_output="$basef.human.snap.unmatched"

if [ "$skip_host_subtraction" != "Y" ]
then
	START_SUBTRACTION=$(date +%s)
	echo -e "$(date)\t$scriptname\t############### HOST SUBTRACTION ###############"
	echo -e "$(date)\t$scriptname\thost_subtract.sh $snap_subtraction_input $cores $SNAP_subtraction_folder $d_human ${snap_subtraction_output}.fastq $basef"
	host_subtract.sh "$snap_subtraction_input" "$cores" "$SNAP_subtraction_folder" "$d_human" "$snap_subtraction_output" "$basef"

	if [[ "$bowtie_subtraction" == "Y" ]]
	then
		host_subtracted_fastq="${snap_subtraction_output}.bt2.unmatched.fastq"
		echo -e "$(date)\t$scriptname\tbowtie2_subtract.sh $snap_subtraction_output $cores $BOWTIE2_FOLDER $host_subtracted_fastq $basef $cutadapted_fastq"
		bowtie2_subtract.sh "$snap_subtraction_output" "$cores" "$BOWTIE2_FOLDER" "$host_subtracted_fastq" "$basef" "$cutadapted_fastq"
	else
		host_subtracted_fastq="${snap_subtraction_output}.fastq"
	fi
	END_SUBTRACTION=$(date +%s)
	diff_SUBTRACTION=$(( END_SUBTRACTION - START_SUBTRACTION ))
	echo -e "$(date)\t$scriptname\tSubtraction took $diff_SUBTRACTION seconds" | tee -a "timing.$basef.log"
else
	# Skip host subtraction step, so use preprocessed file directly
	host_subtracted_fastq="${snap_subtraction_output}.fastq"
	ln -s "$snap_subtraction_input" "$host_subtracted_fastq"
	echo -e "$(date)\t$scriptname\t############### HOST SUBTRACTION - skipped ###############"
fi

if [[ "$exit_after_host_subtraction" == "Y" ]]
then
	echo -e "$(date)\t$scriptname\texiting - exit_after_host_subtraction = $exit_after_host_subtraction." | tee -a "timing.$basef.log"
	exit
fi

# now we have several files existing for use:
#	$snap_subtraction_input (input to SNAP)
#	$snap_subtraction_output (output from SNAP)
#	$host_subtracted_fastq	(output after subtraction, which will include bowtie2 subtraction if used)

############################# SNAP TO NT ##############################

snap_alignment_input="$host_subtracted_fastq"
snap_alignment_output="$basef.NT.snap.tax.matched" # (.sam)

echo -e "$(date)\t$scriptname\t####### SNAP UNMATCHED SEQUENCES TO NT ######"
echo -e -n "$(date)\t$scriptname\tNumber of sequences to analyze using SNAP to NT: "
echo $(awk 'NR%4==1' "$host_subtracted_fastq" | wc -l)
echo -e "$(date)\t$scriptname\tStarting: SNAP alignment to NT of $host_subtracted_fastq..."
START_SNAPNT=$(date +%s)

echo -e "$(date)\t$scriptname\tParameters: snap-dev_nt_combine.sh $host_subtracted_fastq ${SNAP_COMPREHENSIVE_db_dir} $cores $d_NT_alignment $taxonomy_db_directory $snap_omax $snap_om"
snap-dev_nt_combine.sh "$host_subtracted_fastq" "${SNAP_COMPREHENSIVE_db_dir}" "$cores" "$d_NT_alignment" "$taxonomy_db_directory" "$snap_omax" "$snap_om"

echo -e "$(date)\t$scriptname\tCompleted: SNAP alignment to NT of $host_subtracted_fastq."
END_SNAPNT=$(date +%s)
diff_SNAPNT=$(( END_SNAPNT - START_SNAPNT ))
echo -e "$(date)\t$scriptname\tSNAP to NT took $diff_SNAPNT seconds." | tee -a "timing.$basef.log"

host_subtracted_fastq_base=$(basename "$host_subtracted_fastq" .fastq)
mv -f "${host_subtracted_fastq_base}.NT.tax.sam" "${snap_alignment_output}.sam"

if [[ "$exit_after_classification" == "Y" ]]
then
	echo -e "$(date)\t$scriptname\texiting - exit_after_classification = $exit_after_classification." | tee -a "timing.$basef.log"
	exit
fi

############################# Separation into taxonomic annotated files ##############################

matched_fulllength_fastq="$basef.NT.snap.matched.fulllength.fastq"

#define fulllength annotated/sorted filename
fulllength_annotated="$basef.NT.snap.matched.d${d_NT_alignment}.fl.all.annotated"

# main_sorted_file="${fulllength_annotated}.sorted"
viruses="$basef.NT.snap.matched.d${d_NT_alignment}.fl.Viruses.annotated"
bacteria="$basef.NT.snap.matched.d${d_NT_alignment}.fl.Bacteria.annotated"
primates="$basef.NT.snap.matched.d${d_NT_alignment}.fl.Primates.annotated"
nonPrimMammal="$basef.NT.snap.matched.d${d_NT_alignment}.fl.nonPrimMammal.annotated"
nonMammalChordat="$basef.NT.snap.matched.d${d_NT_alignment}.fl.nonMammalChordat.annotated"
nonChordatEuk="$basef.NT.snap.matched.d${d_NT_alignment}.fl.nonChordatEuk.annotated"
plants="$basef.NT.snap.matched.d${d_NT_alignment}.fl.Plants.annotated"
arthropods="$basef.NT.snap.matched.d${d_NT_alignment}.fl.Arthropoda.annotated"
fungi="$basef.NT.snap.matched.d${d_NT_alignment}.fl.Fungi.annotated"
parasite="$basef.NT.snap.matched.d${d_NT_alignment}.fl.Parasite.annotated"
#end of define annotated/sorted filenames


## convert to FASTQ and retrieve full-length sequences
echo -e "$(date)\t$scriptname\tConvert to FASTQ and retrieve full-length sequences for SNAP NT matched hits"
echo -e "$(date)\t$scriptname\tParameters: extractHeaderFromFastq_ncores.sh $cores $cutadapted_fastq ${snap_alignment_output}.sam $matched_fulllength_fastq"
extractHeaderFromFastq_ncores.sh "$cores" "$cutadapted_fastq" "${snap_alignment_output}.sam" "$matched_fulllength_fastq"
sort -k1,1 "${snap_alignment_output}.sam"  > "${snap_alignment_output}.sorted.sam"

cut -f1-9 "${snap_alignment_output}.sorted.sam" > "${snap_alignment_output}.sorted.sam.tmp1"
cut -f12- "${snap_alignment_output}.sorted.sam" > "${snap_alignment_output}.sorted.sam.tmp2"
awk '(NR%4==1) {printf("%s\t",$0)} (NR%4==2) {printf("%s\t", $0)} (NR%4==0) {printf("%s\n",$0)}' "$matched_fulllength_fastq" | sort -k1,1 | awk '{print $2 "\t" $3}' > "${snap_alignment_output}.fulllength.sequence.txt"

#Verify that .tmp1, .tmp2, and .txt have same number of lines before pasting. If not, exit with an error.
tmp1_length=$(wc -l "${snap_alignment_output}.sorted.sam.tmp1" | awk '{print $1}')
tmp2_length=$(wc -l "${snap_alignment_output}.sorted.sam.tmp2" | awk '{print $1}')
txt_length=$(wc -l "${snap_alignment_output}.fulllength.sequence.txt" | awk '{print $1}')
if [[ $tmp1_length == $tmp2_length && $tmp1_length == $txt_length ]]
then
	echo -e "${green}files match in length (.tmp1, .tmp2, .txt).${endColor}"
else
	echo -e "${red}files do not match in length (.tmp1, .tmp2, .txt).${endColor}"
	echo -e "${red}$tmp1_length\t${snap_alignment_output}.sorted.sam.tmp1${endColor}"
	echo -e "${red}$tmp2_length\t${snap_alignment_output}.sorted.sam.tmp2${endColor}"
	echo -e "${red}$txt_length\t${snap_alignment_output}.fulllength.sequence.txt${endColor}"

	exit			
fi
paste "${snap_alignment_output}.sorted.sam.tmp1" "${snap_alignment_output}.fulllength.sequence.txt" "${snap_alignment_output}.sorted.sam.tmp2" > "$fulllength_annotated"

############################# Create annotated files #############################
echo -e "$(date)\t$scriptname\tExtracting taxonomic portions from $fulllength_annotated..."
grep	"Viruses;"			"$fulllength_annotated" 																		> "$viruses"
grep	"Bacteria;"			"$fulllength_annotated" 																		> "$bacteria"
grep    "Primates;"			"$fulllength_annotated" 																		> "$primates"
grep -v "Primates"			"$fulllength_annotated" | grep "Mammalia"														> "$nonPrimMammal"
grep -v "Mammalia"			"$fulllength_annotated" | grep "Chordata"														> "$nonMammalChordat"
grep -v "Chordata"			"$fulllength_annotated" | grep -v "Viridiplantae" | grep "Eukaryota" | grep -v "Arthropoda;"	> "$nonChordatEuk"
grep	"Viridiplantae;"	"$fulllength_annotated" 																		> "$plants"
grep	"Arthropoda;"		"$fulllength_annotated"																			> "$arthropods"
grep	"Fungi;"			"$nonChordatEuk" 																			> "$fungi"
grep -v "Fungi;"			"$nonChordatEuk" 																			> "$parasite"

#create secondary cutoff .annotated files
grep -P 'NM:i:([0-'$d_NT_secondary_cutoff'](?!\d))' "$bacteria" > "$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Bacteria.annotated"
grep -P 'NM:i:([0-'$d_NT_secondary_cutoff'](?!\d))' "$fungi" 	> "$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Fungi.annotated"
grep -P 'NM:i:([0-'$d_NT_secondary_cutoff'](?!\d))' "$parasite" > "$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Parasite.annotated"

############################# Filtering #############################
START_FILTER=$(date +%s)
filter_SURPI_output_v1 "$viruses" Viruses "$eBLASTn_filter" "$cores" "$taxonomy_db_directory" "$BLAST_folder"
END_FILTER=$(date +%s)
diff_FILTER=$(( END_FILTER - START_FILTER ))
echo -e "$(date)\t$scriptname\tFilter procedure took $diff_FILTER seconds" | tee -a "timing.$basef.log"

############################# Create readcounts #############################
echo -e "$(date)\t$scriptname\tStarting: generating readcounts.$basef.log report"
START_READCOUNT=$(date +%s)

headerid=$(head -1 "$basef.fastq" | cut -c1-4 | sed 's/@//g')
echo -e "$(date)\t$scriptname\theaderid_top $headerid_top = headerid_bottom $headerid_bottom and headerid = $headerid"
if [[ $SSD = 1 ]]
then
	readcount="readcount -parallel"
else
	readcount="readcount"
fi
$readcount -base "$basef" -header "$headerid" \
		"$basef.fastq" \
		"$basef.preprocessed.fastq" \
		"${snap_subtraction_output}.fastq" \
		"$host_subtracted_fastq" \
		"$fulllength_annotated" \
		"$arthropods" \
		"$nonMammalChordat" \
		"$viruses" \
		"$nonPrimMammal" \
		"$plants" \
		"$bacteria" \
		"$fungi" \
		"$parasite" \
		"$basef.NT.snap.matched.d${d_NT_alignment}.fl.Viruses.filt.NTblastn_tru.dust.annotated" \
		"$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Bacteria.annotated" \
		"$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Fungi.annotated" \
		"$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Parasite.annotated"

echo -e "$(date)\t$scriptname\tDone: generating readcounts.$basef.log report"
END_READCOUNT=$(date +%s)
diff_READCOUNT=$(( END_READCOUNT - START_READCOUNT ))
echo -e "$(date)\t$scriptname\tGenerating read count report Took $diff_READCOUNT seconds" | tee -a "timing.$basef.log"

############################# Create counttables #############################
counttable -ntc -tax_species "$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Bacteria.annotated"
counttable -ntc -tax_species "$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Fungi.annotated"
counttable -ntc -tax_species "$basef.NT.snap.matched.d${d_NT_secondary_cutoff}.fl.Parasite.annotated"

############################# Create Excel Summary files #############################

readcounts_file="readcounts.$basef.BarcodeR1R2.log"

summarizeReadCounts.py -r "$readcounts_file" "$basef" "$excel_template" \
	"$basef.NT.snap.matched.d16.fl.Viruses.filt.NTblastn_tru.dust.annotated.species.clx.counttable" \
	"$basef.NT.snap.matched.d16.fl.Viruses.filt.NTblastn_tru.dust.annotated.subspp.clx.counttable" \
	"$basef.NT.snap.matched.d1.fl.Bacteria.annotated.species.clx.ntc.counttable" \
	"$basef.NT.snap.matched.d1.fl.Parasite.annotated.species.clx.ntc.counttable" \
	"$basef.NT.snap.matched.d1.fl.Fungi.annotated.species.clx.ntc.counttable" \
	"$basef.NT.snap.matched.d1.fl.Bacteria.annotated.species.clx.counttable" \
	"$basef.NT.snap.matched.d1.fl.Fungi.annotated.species.clx.counttable" \
	"$basef.NT.snap.matched.d1.fl.Parasite.annotated.species.clx.counttable"

echo -e "$(date)\t$scriptname\t#################### SURPI PIPELINE COMPLETE ##################"
END_PIPELINE=$(date +%s)
diff_PIPELINE=$(( END_PIPELINE - START_PIPELINE ))
echo -e "$(date)\t$scriptname\tTotal run time of pipeline took $diff_PIPELINE seconds" | tee -a "timing.$basef.log"

echo "Script and Parameters = $0 $@ " > "$basef.pipeline_parameters.log"
echo "Raw Read quality = $quality" >> "$basef.pipeline_parameters.log"
echo "Raw Read length = $length" >> "$basef.pipeline_parameters.log"
echo "Read length_cutoff for preprocessing under which reads are thrown away = $length_cutoff" >> "$basef.pipeline_parameters.log"

echo "SURPI_db_directory housing the reference databases for Comprehensive Mode: $SNAP_COMPREHENSIVE_db_dir" >> "$basef.pipeline_parameters.log"

echo "SNAP edit distance for SNAP to Human and SNAP to NT d_human = $d_human" >> "$basef.pipeline_parameters.log"
echo "adapter_set = $adapter_set" >> "$basef.pipeline_parameters.log"

########CLEANUP############

dataset_folder="DATASETS_$basef"
log_folder="LOG_$basef"
output_folder="OUTPUT_$basef"
trash_folder="TRASH_$basef"

mkdir "$dataset_folder"
mkdir "$log_folder"
mkdir "$output_folder"
mkdir "$trash_folder"

#Move files to DATASETS
mv "$basef.NT.snap.matched.fulllength.sam" "$dataset_folder"
if [ -e "$basef.NT.snap.unmatched.uniq.fl.fastq" ]; then mv "$basef.NT.snap.unmatched.uniq.fl.fastq" "$dataset_folder"; fi

#Move files to LOG
mv "$basef.cutadapt.summary.log" "$log_folder"
mv "$basef.adapterinfo.log" "$log_folder"
mv "$basef.cutadapt.cropped.fastq.log" "$log_folder"
mv "$basef.preprocess.log" "$log_folder"
mv "$basef.pipeline_parameters.log" "$log_folder"
mv $basef*.snap.log "$log_folder"
mv $basef*.time.log "$log_folder"
mv "quality.$basef.log" "$log_folder"

#Move files to OUTPUT
if [ -e "$basef.$illumina_samplesheet" ]; then mv "$basef.$illumina_samplesheet" "$output_folder"; fi
mv "$fulllength_annotated" "$output_folder"
mv "$viruses" "$output_folder"
mv "$bacteria" "$output_folder"
mv "$primates" "$output_folder"
mv "$nonPrimMammal" "$output_folder"
mv "$nonMammalChordat" "$output_folder"
mv "$nonChordatEuk" "$output_folder"
mv readcounts.$basef.*log "$output_folder"
mv "timing.$basef.log" "$output_folder"
mv $basef*table "$output_folder"
if [ -e "$basef.quality" ]; then mv "$basef.quality" "$output_folder"; fi
mv *.annotated "$output_folder"
mv FILTER_LEFTOVER_$basef* "$output_folder"
mv *.xlsx "$output_folder"
mv *.alignment.db "$output_folder"

#Move files to TRASH
mv "$basef.cutadapt.fastq" "$trash_folder"
mv "$basef.preprocessed.fastq" "$trash_folder"
mv "$basef.cutadapt.cropped.dusted.bad.fastq" "$trash_folder"
if [ -e "temp.sam" ]; then mv "temp.sam" "$trash_folder"; fi
mv "$basef.NT.snap.matched.fulllength.fastq" "$trash_folder"
mv "$basef.NT.snap.tax.matched.sam" "$trash_folder"
mv "$basef.NT.snap.unmatched.sam" "$trash_folder"
mv "$basef.NT.snap.matched.sorted.sam" "$trash_folder"
mv "$basef.NT.snap.matched.sorted.sam.tmp2" "$trash_folder"
if [ -e "$basef.NT.snap.unmatched.fastq" ]; then mv "$basef.NT.snap.unmatched.fastq" "$trash_folder"; fi
if [ -e "$basef.NT.snap.matched.fastq" ]; then mv "$basef.NT.snap.matched.fastq" "$trash_folder"; fi
mv "$basef.NT.snap.matched.sorted.sam.tmp1" "$trash_folder"
mv "$basef.NT.snap.matched.fulllength.all.annotated" "$trash_folder"
mv "$basef.NT.snap.matched.fulllength.sequence.txt" "$trash_folder"
mv "$basef.NT.snap.matched.fulllength.gi.taxonomy" "$trash_folder"
mv "$basef.NT.snap.matched.fl.Viruses.fastq" "$trash_folder"
mv "$basef.NT.snap.matched.fl.Viruses.fasta" "$trash_folder"
mv "$basef.NT.snap.matched.fl.Viruses.uniq.fasta" "$trash_folder"
mv "$basef.NT.snap.matched.fulllength.gi.uniq" "$trash_folder"
mv "$basef.NT.snap.tax.matched.header" "$trash_folder"

cp "SURPI.$basef.log" "$output_folder"
cp "SURPI.$basef.err" "$output_folder"
cp "$basef.config" "$output_folder"
cp "$log_folder/quality.$basef.log" "$output_folder"

