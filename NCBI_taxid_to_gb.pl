#!/usr/bin/perl -w
#
#	This program will take a taxid as input, and return all the corresponding gi
#	Chiu Laboratory
#	University of California, San Francisco
#
# Copyright (C) 2014 Scot Federman - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.

use DBI;
use Getopt::Std;
use Time::HiRes qw[gettimeofday tv_interval];

my $counter = 0;
my $dbfile;
my $ref_folder;
our ($opt_h, $opt_g, $opt_d, $opt_i, $opt_t, $opt_q);
getopts('hgd:i:t:q:');

if ($opt_h) {
	print <<USAGE;
	
NCBI_taxid_to_gb.pl


This program will extract a list of Genbank identifiers for a given NCBI taxonomical unit name.
	

Usage:

To look up taxonomy for a file containing identifier
	NCBI_taxid_to_gb.pl -i list.taxid -d nucl

Command Line Switches:

	-h	Show help & ignore all other switches
	-g	Look up GI (default: accession)
	-i	Specify input file containing list of taxid, one per line
	-t	Specify single taxid
	-d	Specify molecular type to return (nucl/prot)
	-q	folder containing taxonomy databases
		This folder should contain the 3 SQLite files created by the script "create_taxonomy_db.sh"
			(acc|gi)_taxid_nucl.db - nucleotide db of (acc|gi)/taxonid
			(acc|gi)_taxid_prot.db - protein db of (acc|gi)/taxonid
			names_nodes_scientific.db - db of taxonid/taxonomy
	
USAGE
	exit;
}

$taxid_file = $opt_i;
$taxid_input = $opt_t;

# Set reference folder location
if ( $opt_q ) {
	$ref_folder = $opt_q;
}
else {
	$ref_folder="/reference/taxonomy";
}

if ( $opt_g ) {
	$nucleotide_db = "$ref_folder/gi_taxid_nucl.db";
	$protein_db = "$ref_folder/gi_taxid_prot.db";
	$sql = 'SELECT gi FROM gi_taxid WHERE taxid = ?';
}
else {
	$nucleotide_db = "$ref_folder/acc_taxid_nucl.db";
	$protein_db = "$ref_folder/acc_taxid_prot.db";
	$sql = 'SELECT acc FROM acc_taxid WHERE taxid = ?';
}

if ($opt_d eq "nucl") {
	$dbfile = $nucleotide_db;
}
elsif ($opt_d eq "prot") {
	$dbfile = $protein_db;
}
else {
	print "\nImproper database specified. Please use nucl or prot with the -d switch.\n\n";
	exit;
}

my $dsn = "dbi:SQLite:dbname=$dbfile";

my $dbh = DBI->connect($dsn, "", "", {
	RaiseError => 1, 
	AutoCommit => 1
}) or die $DBI::errstr;

my $sth = $dbh->prepare($sql);

if ($taxid_file) {
	open my $taxid_file, '<', $taxid_file or die "Can't open $taxid_file: $!";
	while (my $taxid = <$taxid_file>) {
		chomp $taxid;
		$sth->execute($taxid);
		while (my @row = $sth->fetchrow_array) {
			print "$row[0]\n";
		}
	}
	close $taxid_file;
}
elsif ($taxid_input) {
	$sth->execute($taxid_input);
	while (my @row = $sth->fetchrow_array) {
		print "$row[0]\n";
	}
}
$dbh->disconnect;
