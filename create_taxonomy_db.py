#!/usr/bin/python
#
#	create_taxonomy_db.py
#
#	This program creates the SQLite taxonomy database used by SURPI
#	Chiu Laboratory
#	University of California, San Francisco
#
# Copyright (C) 2014 Scot Federman - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.

import sqlite3
import sys

def create_names_nodes():
	print ("Creating names_nodes_scientific.db...")
	conn, c = connect('names_nodes_scientific.db')

	# can be empty but must exist
	c.execute('''CREATE TABLE "tags" (taxid INTEGER PRIMARY KEY, host TEXT)''')

	c.execute('''CREATE TABLE names (
				taxid INTEGER PRIMARY KEY,
				name TEXT)''')
	c.execute("CREATE INDEX IF NOT EXISTS nameIdx ON names (name)")

	with open('names_scientificname.dmp', 'rU') as f:
		for line in f:
			line = line.split("|")
			taxid = line[0].strip()
			name = line[1].strip()
			c.execute("INSERT INTO names VALUES (?,?)", (taxid, name))

	c.execute('''CREATE TABLE nodes (
				taxid INTEGER PRIMARY KEY,
				parent_taxid INTEGER, 
				rank TEXT,
				division_id INTEGER)''')
	c.execute("CREATE INDEX IF NOT EXISTS rankIdx ON nodes (rank)")
	c.execute("CREATE INDEX IF NOT EXISTS dividIdx ON nodes (division_id)")
	c.execute("CREATE INDEX IF NOT EXISTS parentIdx ON nodes (parent_taxid)")

	with open('nodes.dmp', 'rU') as f:
		for line in f:
			line = line.split("|")
			taxid = line[0].strip()
			parent_taxid = line[1].strip()
			rank = line[2].strip()
			div_id = line[4].strip()
			c.execute ("INSERT INTO nodes VALUES (?,?,?,?)", (taxid, parent_taxid, rank, div_id))

	conn.commit()
	conn.close()


def createGILookup():
	print ("Creating gi_taxid_nucl.db...")
	conn, c = connect('gi_taxid_nucl.db')

	c.execute('''CREATE TABLE gi_taxid (
				gi INTEGER PRIMARY KEY,
				taxid INTEGER)''')
	c.execute("CREATE INDEX tax_index ON gi_taxid (taxid);")
	insertGI(c, 'gi_taxid_nucl.dmp')

	conn.commit()
	conn.close()

def insertGI(cursor, fName):
	with open(fName, 'rU') as f:
		for line in f:
			line = line.split()
			cursor.execute("INSERT INTO gi_taxid VALUES (?,?)", (line[0], line[1]))


def createAccessionLookup():
	print ("Creating acc_taxid_nucl.db...")
	conn, c = connect('acc_taxid_nucl.db')

	c.execute('''CREATE TABLE acc_taxid (
				acc TEXT PRIMARY KEY,
				taxid INTEGER)''')
	c.execute ("CREATE INDEX tax_index ON acc_taxid (taxid);")
	insertAccession(c, 'nucl_gb.accession2taxid')

	conn.commit()
	conn.close()

	print ("Creating acc_taxid_prot.db...")
	conn, c = connect('acc_taxid_prot.db')

	c.execute('''CREATE TABLE acc_taxid (
				acc TEXT PRIMARY KEY, 
				taxid INTEGER)''')
	c.execute ("CREATE INDEX tax_index ON acc_taxid (taxid);")
	insertAccession(c, 'prot.accession2taxid')

	conn.commit()
	conn.close()

def insertAccession(cursor, fName):
	heading = True
	with open(fName, 'rU') as f:
		for line in f:
			line = line.split()
			if heading:
				assert line[0] == 'accession'
				heading = False
				continue
			cursor.execute("INSERT INTO acc_taxid VALUES (?,?)", (line[0], line[2]))


def mergeTaxids(ref):
	print ("Merging tax IDs...")
	conn, c = connect('%s_taxid_nucl.db' % ref)

	with open('merged.dmp', 'rU') as f:
		for line in f:
			line = line.split()
			c.execute("UPDATE %s_taxid SET taxid = ? WHERE taxid = ?" % ref, (line[2], line[0]))

	conn.commit()
	conn.close()

# A crash or power failure could corrupt the database but that is
# small risk compared to the improved throughput.
def connect(dbName):
	conn = sqlite3.connect(dbName, isolation_level="EXCLUSIVE")
	c = conn.cursor()
	c.execute("PRAGMA synchronous=OFF")
	c.execute("PRAGMA journal_mode=OFF")
	c.execute("PRAGMA locking_mode=EXCLUSIVE")
	return conn, c

def main():
	create_names_nodes()
	if GI:
		ref = 'gi'
		createGILookup()
	else:
		ref = 'acc'
		createAccessionLookup()
	if merge:
		mergeTaxids(ref)


def version():
	import os.path
	print os.path.basename(sys.argv[0]), 'v2.0'
	sys.exit(0)

def usage(msg=None):
	print "Create the SQLite taxonomy databases used by SURPI."
	print
	print "Usage: %s [--version] [--gi]" % sys.argv[0]
	print "  --gi: create GI-based mappings to taxid (default: use accession)"
	print "Pre-populates the clinical analysis report with SURPI data."
	if msg is not None:
		print msg

if __name__ == '__main__':
	import getopt
	GI = False
	merge = False
	options, args = getopt.getopt(sys.argv[1:], "", ['gi', 'merge', 'version'])
	try:
		for option, value in options:
			if option == '--gi':
				GI = True
			elif option == '--merge':
				merge = True
			elif option == '--version':
				version()
				sys.exit()
	except getopt.GetoptError, msg:
		usage(msg)
		sys.exit(2)

	main()
