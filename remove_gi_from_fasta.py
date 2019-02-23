#!/usr/bin/env python

#This program receives 3 arguments:
# 1 - Input file (in FASTA format)
# The assumption is that the header is in the following format:
# name is gi|4|emb|X17276.1|
# i.e. gi is the second field, using | as a delimiter

# 2 - gi list - these gi will be removed from the inputfile
# 3 - Output filename (in FASTA format)
import re
import sys
from Bio import SeqIO

usage = "remove_gi_from_fasta.py <inputfile (FASTA)> <gi to remove> <output file (retained FASTA)> <output file (removed FASTA)>"

if len(sys.argv) < 3:
	print usage
	sys.exit(0)


fasta_file = sys.argv[1]  # Input fasta file
gi_to_remove_file = sys.argv[2] # Input wanted file, one gene name per line
result_file = sys.argv[3] # Output fasta file
remove_file = sys.argv[4] # Output removed sequences FASTA file

remove = set()
with open(gi_to_remove_file) as f:
	for line in f:
		line = line.strip()
		if line != "":
			remove.add(line)

fasta_sequences = SeqIO.parse(open(fasta_file),'fasta')

retained_sequences = 0
removed_sequences = 0

# Example nt entry
# >gi|33|emb|X60496.1| B.taurus exon 2 for bovine seminal vesicle secretory...
# Example nt.reducedheaders entry
# >gi|33| B.taurus exon 2 for bovine seminal vesicle secretory...
# strip here
# 33
reGI = re.compile(r'^gi\|(\d+)\|.*$')
with open(result_file, "w") as f, open(remove_file, "w") as g:
	for fasta in fasta_sequences:
		name = fasta.id
		m = reGI.match(name)
		if m is not None and m.group(1) not in remove and len(name) > 0:
			SeqIO.write([fasta], f, "fasta")
			retained_sequences +=1
		else:
			SeqIO.write([fasta], g, "fasta")
			removed_sequences +=1

print "# sequences retained: ", retained_sequences
print "# sequences removed:", removed_sequences
