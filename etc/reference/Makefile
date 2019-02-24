# build the reference dataset

# Makefile notes
# Substitutions occur before target name is evaluated so if making target directly use substituted value,
# e.g., "make ncbi/fasta/nt_modulo20"
# Using a file list for prerequisite and target means the target recipe will be
# called once for each prerequisite. 
# The mtime (modification time) on a directory changes when a file or
# a subdirectory is added, removed or renamed.
# make -n <target> will output build plan without building (useful for identifying any missing files, etc.)
# make -d -n <target> will print detailed logic of build plan without building

# Usage example:
# REFERENCE=/home/stryke/reference
# singularity exec --app SURPI --bind ${REFERENCE} SURPI.sqsh bash -c "cp -r /scif/apps/SURPI/SURPI/etc/reference/* ${REFERENCE} ; make -C ${REFERENCE} all"

# Audit trail
DATE := "20150304"
NT := nt_$(DATE)

# Various indexing parameters
HUMAN_SEED := 20
CURATED_LOCATION_SIZE := 5
CURATED_SNAP_INDICES := 4
RIBO_LOCATION_SIZE := 4
RIBO_SEED := 16

# taxonomy tagging list
TAG_DB_FILE := tagging_list_5.txt

# NCBI source data
NCBI := "ftp://ftp.ncbi.nih.gov"
TAXONOMY_DB_FILES := gi_taxid_nucl.db names_nodes_scientific.db
TAXONOMY_DB_FILE_PATHS := $(addprefix build/taxonomy/,$(TAXONOMY_DB_FILES)) 

# Ensembl source data
ENSEMBL := "ftp://ftp.ensembl.org/pub/current_fasta/homo_sapiens/dna"

BLASTNTDB := $(shell if [ -e "BLASTDB/nt.nhr" ] ; then echo "BLASTDB/nt.nhr" ; else echo "BLASTDB/nt.00.nhr" ; fi)

REF := GI

.PHONY: all download clean

# Since some steps can takes days to complete, we download all files first to obtain comtemporaneous datasets.

all: download COMP_SNAP_no_prim_research snap_hg38_primate bowtie2_hg38 BLASTDB taxonomy ncbi/boltdb Vector_SNAP/snap_UniVec RiboClean_SNAP1.0 

download: ncbi/fasta/nt.gz ncbi/fasta/UniVec ncbi/taxonomy/taxdump.tar.gz ensembl/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz

clean:
	rm -rf BLASTDB bowtie2_hg38 build COMP_SNAP_no_primate COMP_SNAP_no_prim_research ncbi/boltdb RiboClean_SNAP1.0 snap_hg38 snap_hg38_primate snap_primate taxonomy Vector_SNAP

#
# snap human and primate subtraction databases
#

snap_hg38_primate: \
	snap_hg38/snap_index_Homo_sapiens.GRCh38.dna_sm.primary_assembly_s$(HUMAN_SEED)/Genome \
	snap_primate/snap_nt_curated_primate.FASTA/Genome
	mkdir -p snap_hg38_primate
	cd snap_hg38_primate && ln -sf ../snap_primate/snap_nt_curated_primate.FASTA
	cd snap_hg38_primate && ln -sf ../snap_hg38/snap_index_Homo_sapiens.GRCh38.dna_sm.primary_assembly_s$(HUMAN_SEED)

#
# snap human subtraction database
#

snap_hg38/snap_index_Homo_sapiens.GRCh38.dna_sm.primary_assembly_s$(HUMAN_SEED)/Genome: ensembl/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa
	mkdir -p snap_hg38
	cd snap_hg38 && snap-dev index ../ensembl/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa "snap_index_Homo_sapiens.GRCh38.dna_sm.primary_assembly_s$(HUMAN_SEED)" -s "$(HUMAN_SEED)"

#
# snap primate subtraction database
#

snap_primate/snap_nt_curated_primate.FASTA/Genome: build/nt_curated_primate.FASTA
	mkdir -p snap_primate
	cd snap_primate && snap-dev index ../build/nt_curated_primate.FASTA snap_nt_curated_primate.FASTA -bSpace -locationSize $(CURATED_LOCATION_SIZE)

#
# snap no primate mapping database
#

COMP_SNAP_no_prim_research: COMP_SNAP_no_primate/snap_index_nt_curated_primate_subtracted.FASTA.1/Genome
	mkdir -p COMP_SNAP_no_prim_research
	cd COMP_SNAP_no_prim_research && \
		rm -f snap_index_* ; \
		for f in ../COMP_SNAP_no_primate/snap_index_nt_curated_primate_subtracted.FASTA.* ; do \
			ln -s "$$f" ; \
			done ; \

COMP_SNAP_no_primate/snap_index_nt_curated_primate_subtracted.FASTA.1/Genome: build/nt_curated_primate_subtracted.FASTA.1
	mkdir -p COMP_SNAP_no_primate
	cd COMP_SNAP_no_primate && \
		rm -rf snap_index_nt_curated_primate_subtracted.* ; \
		for f in ../build/nt_curated_primate_subtracted.FASTA.* ; do \
			n=`basename "$$f"` ; \
			snap-dev index "$$f" "snap_index_$$n" -bSpace -locationSize $(CURATED_LOCATION_SIZE) ; \
			done

build/nt_curated_primate_subtracted.FASTA.1: build/nt_curated_primate_subtracted.FASTA | build
	cd build && rm -f nt_curated_primate_subtracted.FASTA.*
	cd build && gt splitfasta -numfiles $(CURATED_SNAP_INDICES) nt_curated_primate_subtracted.FASTA

#
# Blast filtering
#

BLASTDB: $(BLASTNTDB)

$(BLASTNTDB): build/nt_curated.fa
	mkdir -p BLASTDB
	cd BLASTDB && makeblastdb -in ../build/nt_curated.fa -dbtype nucl -out nt -title nt -parse_seqids

#
# Boltdb reference database
#

ncbi/boltdb: ncbi/boltdb/nt/nt.data.db
	cd ncbi/boltdb && ln -sf nt_$(DATE) nt

ncbi/boltdb/nt/nt.data.db: taxonomy/names_nodes_scientific.db build/nt_curated.fa
	mkdir -p ncbi/boltdb/nt_$(DATE)
ifeq ($(REF),GI)
	coveragedb -id gi -dbname nt -output ncbi/boltdb/nt_$(DATE) taxonomy build/nt_curated.fa
else
	coveragedb -dbname nt -output ncbi/boltdb/nt_$(DATE) taxonomy build/nt_curated.fa
endif

#
# NCBI reference sequence curation
#

build/nt_curated_primate_subtracted.FASTA build/nt_curated_primate.FASTA: build/nt_curated.fa build/Primates_9443_nucl.gb | build
ifeq ($(REF),GI)
	cd build && remove_gi_from_fasta.py nt_curated.fa Primates_9443_nucl.gb nt_curated_primate_subtracted.FASTA nt_curated_primate.FASTA
else
	cd build && remove_acc_from_fasta.py nt_curated.fa Primates_9443_nucl.gb nt_curated_primate_subtracted.FASTA nt_curated_primate.FASTA
endif

build/Primates_9443_nucl.gb: taxonomy/names_nodes_scientific.db | build
ifeq ($(REF),GI)
	cd build && NCBI_name_to_gb.sh -g -n "Primates" -q ../taxonomy -d nucl
else
	cd build && NCBI_name_to_gb.sh -n "Primates" -q ../taxonomy -d nucl
endif

build/nt_curated.fa build/nt_removed.fa: ncbi/fasta/nt taxonomy/names_nodes_scientific.db | build
ifeq ($(REF),GI)
	cd build && create_curated_nt.sh -g -i ../ncbi/fasta/nt -q ../taxonomy 
else
	cd build && create_curated_nt.sh -i ../ncbi/fasta/nt -q ../taxonomy 
endif

#
# Vector sequence filtering
#

Vector_SNAP/snap_UniVec: ncbi/fasta/UniVec
	mkdir -p Vector_SNAP
	rm -rf Vector_SNAP/snap_UniVec
	cd Vector_SNAP && snap-dev index ../ncbi/fasta/UniVec snap_UniVec

#
# NCBI reference sequences
#

ncbi/fasta/nt: ncbi/fasta/nt.gz
	cd ncbi/fasta && \
		mv nt.gz.md5 $(NT).gz.md5 ; \
		mv nt.gz $(NT).gz ; \
		ln -sf $(NT).gz nt.gz ; \
		pigz -T -d -c nt.gz >| $(NT) ; \
		ln -sf $(NT) nt

ncbi/fasta/nt.gz ncbi/taxonomy/taxdump.tar.gz ncbi/taxonomy/gi_taxid_nucl.dmp.gz:
	mkdir -p ncbi/fasta
	cd ncbi/fasta && \
		download_surpiplus_dbs ; \
		md5sum -c --status nt.gz.md5 ; \
		md5sum -c --status taxdump.tar.gz.md5 ; \
		md5sum -c --status gi_taxid_nucl.dmp.gz.md5
	mkdir -p ncbi/taxonomy
	cd ncbi/taxonomy && \
		mv ../fasta/taxdump.tar.gz* . ; \
		mv ../fasta/gi_taxid_nucl.dmp.gz* .

# NCBI Vector sequences
ncbi/fasta/UniVec:
	mkdir -p ncbi/fasta
	cd ncbi/fasta && curl -L -O $(NCBI)/pub/UniVec/UniVec

#
# bowtie2 human subtraction database
#

bowtie2_hg38: bowtie2_hg38/bowtie2_Homo_sapiens.GRCh38.dna_sm.primary_assembly/bowtie2_Homo_sapiens.GRCh38.dna_sm.primary_assembly.1.bt2

bowtie2_hg38/bowtie2_Homo_sapiens.GRCh38.dna_sm.primary_assembly/bowtie2_Homo_sapiens.GRCh38.dna_sm.primary_assembly.1.bt2: ensembl/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa
	mkdir -p bowtie2_hg38/bowtie2_Homo_sapiens.GRCh38.dna_sm.primary_assembly
	cd bowtie2_hg38/bowtie2_Homo_sapiens.GRCh38.dna_sm.primary_assembly && bowtie2-build ../../ensembl/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa bowtie2_Homo_sapiens.GRCh38.dna_sm.primary_assembly

#
# Ensembl reference sequences
#

ensembl/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa: ensembl/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz
	cd ensembl && pigz -T -d --keep Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz

ensembl/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz: 
	mkdir -p ensembl
	cd ensembl && curl -O "$(ENSEMBL)/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa.gz"

#
# RiboClean curated databases for filtering
#

RiboClean_SNAP1.0: RiboClean_SNAP1.0/snap_bacteria.fa_s$(RIBO_SEED) RiboClean_SNAP1.0/snap_eukaryote.fa_s$(RIBO_SEED)

RiboClean_SNAP1.0/snap_bacteria.fa_s$(RIBO_SEED): chiulab/RiboClean/bacteria.fa
	mkdir -p RiboClean_SNAP1.0
	rm -rf RiboClean_SNAP1.0/snap_bacteria.fa_s$(RIBO_SEED)
	cd RiboClean_SNAP1.0 && snap-dev index ../chiulab/RiboClean/bacteria.fa snap_bacteria.fa_s$(RIBO_SEED) -locationSize $(RIBO_LOCATION_SIZE) -s $(RIBO_SEED)

chiulab/RiboClean/bacteria.fa: chiulab/RiboClean/23s.fa chiulab/RiboClean/rdp_typed_iso_goodq_9210seqs.fa
	cat $^ >| chiulab/RiboClean/bacteria.fa

RiboClean_SNAP1.0/snap_eukaryote.fa_s$(RIBO_SEED): chiulab/RiboClean/eukaryote.fa
	mkdir -p RiboClean_SNAP1.0
	rm -rf RiboClean_SNAP1.0/snap_eukaryote.fa_s$(RIBO_SEED)
	cd RiboClean_SNAP1.0 && snap-dev index ../chiulab/RiboClean/eukaryote.fa snap_eukaryote.fa_s$(RIBO_SEED) -locationSize $(RIBO_LOCATION_SIZE) -s $(RIBO_SEED)

chiulab/RiboClean/eukaryote.fa: chiulab/RiboClean/28s_rRNA_gene_NOT_partial_18s_spacer_5.8s.fa chiulab/RiboClean/18s_rRNA_gene_not_partial.fa
	cat $^ >| chiulab/RiboClean/eukaryote.fa

#
# NCBI taxonomy database
#

# Create taxonomy SQLite databases

taxonomy: taxonomy/names_nodes_scientific.db

taxonomy/names_nodes_scientific.db: build/taxonomy/names_scientificname.dmp build/taxonomy/gi_taxid_nucl.dmp | build
	mkdir -p taxonomy/taxonomy_$(DATE)
ifeq ($(REF),GI)
	cd build/taxonomy && create_taxonomy_db.py --gi --merge
else
	cd build/taxonomy && create_taxonomy_db.py --merge
endif
	cd build/taxonomy && tagTaxonomy.py load --tagfile ../../chiulab/$(TAG_DB_FILE) --taxdb names_nodes_scientific.db
	# Create denormalized table from taxonomy and tags
	taxonomy -gi -load lookup build/taxonomy
	cd build/taxonomy && mv $(TAXONOMY_DB_FILES) ../../taxonomy/taxonomy_$(DATE)/
	cd taxonomy && for f in $(TAXONOMY_DB_FILES) ; do \
		ln -sf taxonomy_$(DATE)/$$f ; \
		done

# Intermediate build files in build/taxonomy
# taxdump contains multiple files
build/taxonomy/names_scientificname.dmp: build/taxonomy/names.dmp | build
	# The below grep "fixes" the issue whereby aliases, mispellings, and other alternate names are returned.
	# We could simply look for a name that is a "scientific name",
	# but this shrinks the db a bit, speeding up lookups, and removes data we do not need at this time.
	cd build/taxonomy && grep "scientific name" names.dmp >| names_scientificname.dmp

build/taxonomy/gi_taxid_nucl.dmp: ncbi/taxonomy/gi_taxid_nucl.dmp.gz | build
	mkdir -p build/taxonomy
	cd ncbi/taxonomy && pigz -T -d -c gi_taxid_nucl.dmp.gz >| ../../build/taxonomy/gi_taxid_nucl.dmp 

build/taxonomy/names.dmp: ncbi/taxonomy/taxdump.tar.gz | build
	mkdir -p build/taxonomy
	tar -xz -C build/taxonomy -f ncbi/taxonomy/taxdump.tar.gz
	touch build/taxonomy/names.dmp

build:
	mkdir -p build
