#!/usr/bin/env python

#This program receives 3 arguments:
# 1 - Input file (in FASTA format)
# The assumption is that the header is in the following format:
# >X17276.1 Descriptive text
# i.e. accession is the first field, using space as a delimiter

# 2 - acc list - these accessions will be removed from the inputfile
# 3 - Output filename (in FASTA format)
import re
import sys
from Bio import SeqIO

usage = "remove_acc_from_fasta.py <inputfile (FASTA)> <acc to remove> <output file (retained FASTA)> <output file (removed FASTA)>"

if len(sys.argv) < 3:
	print usage
	sys.exit(0)


fasta_file = sys.argv[1]  # Input fasta file
acc_to_remove_file = sys.argv[2] # Input wanted file, one gene name per line
result_file = sys.argv[3] # Output fasta file
remove_file = sys.argv[4] # Output removed sequences FASTA file

remove = set()
with open(acc_to_remove_file) as f:
	for line in f:
		line = line.strip()
		if line != "":
			remove.add(line)

fasta_sequences = SeqIO.parse(open(fasta_file),'fasta')

retained_sequences = 0
removed_sequences = 0

# Example nt entry
# >X17276.1 Giant Panda satellite 1 DNA
# But taxonomy accession lookup lacks version numbers so strip here
# X17276
reAcc = re.compile(r'^([^.\s]+).*$')
with open(result_file, "w") as f, open(remove_file, "w") as g:
	for fasta in fasta_sequences:
		name = fasta.id
		m = reAcc.match(name)
		if m is not None and m.group(1) not in remove and len(name) > 0:
			SeqIO.write([fasta], f, "fasta")
			retained_sequences +=1
		else:
			SeqIO.write([fasta], g, "fasta")
			removed_sequences +=1

print "# sequences retained: ", retained_sequences
print "# sequences removed:", removed_sequences
