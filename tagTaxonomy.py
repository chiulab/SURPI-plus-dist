#!/usr/bin/env python
#
#	tagTaxonomy.py
#
#	This scripts has three commands:
#	- Clean a tagging file.
#	- Load a tags database table from a tagging file in a reference taxonomy
#		database.
#	- Search a reference taxonomy database for nodes containing specified
#		text or words and collate these into a new or with an existing 
#		tagging file.
#	- Validate a tagging file.
#	
#	Chiu Laboratory
#	University of California, San Francisco
#	January, 2014
#
# Last revised 2015-11-08
#

import operator
import os
import re
import sqlite3
import string
import sys

RANKS = ['family', 'genus', 'species']

def logHeader():
	import os.path, sys, time
	return "%s\t%s\t" % (time.strftime("%a %b %d %H:%M:%S %Z %Y"), os.path.basename(sys.argv[0]))


class TaxonTag(object):
	"""TaxonTag represents the tags assigned to a single taxon, i.e., one row in a tagging file."""

	# column headings
	ranks = [] # the ranks, e.g., Family, Genus, Species
	categories = [] # the tag categories, e.g., host

	@classmethod
	def setRanks(cls, ranks):
		if not cls.ranks:
			cls.ranks = ranks
		else:
			assert cls.ranks == ranks, "%s != %s" % (cls.ranks, ranks)

	@classmethod
	def setCategories(cls, categories):
		if not cls.categories:
			cls.categories = categories
		else:
			assert len(categories) == 1
			if categories[0] not in cls.categories:
				cls.categories.append(categories[0])

	def __init__(self, taxa, tagDict):
		self.taxa = taxa # the taxa values for family, genus, and species
		self.tagDict = tagDict # the tag values, i.e., tag column category to tag row value


# for now assume tab-delimited file
def readTagFile(tagFile):
	# tagsDict = {(name, rank): TaxonTag()}
	tagsDict = {}
	ranks = []
	tagStartIndex = None
	badLines = []
	with open(tagFile, 'rU') as f:
		for line in f:
			if not line.strip():
				continue

			# find and record the labels, assuming only that species is present
			# and discovering the rest
			if not ranks:
				labels = map(string.lower, line.split())
				if 'species' not in labels:
					continue
				else:
					speciesIndex = labels.index('species')
					ranks = labels[:speciesIndex + 1]
					TaxonTag.setRanks(ranks)
					TaxonTag.setCategories(labels[speciesIndex + 1:])
					continue

			# validate the line
			cols = [col.strip() for col in line.split('\t')]
			if len(cols) < len(TaxonTag.ranks):
				badLines.append(line)
				continue

			for i in range(speciesIndex, -1, -1):
				if not cols[i]:
					# no name in cell
					continue

				key = (cols[i], TaxonTag.ranks[i])
				if key in tagsDict:
					print "%sduplicate tag entry for '%s': dropping duplicate" % (logHeader(), key)
					break

				tagDict = {}
				for j, category in enumerate(TaxonTag.categories):
					tag = cols[speciesIndex + 1 + j]
					if tag:
						tagDict[category] = tag

				if tagDict:
					tagsDict[key] = TaxonTag(tuple(cols[:speciesIndex+1]), tagDict)

				# we record only the first rank entry in the line
				break
				
	if badLines:
		for line in badLines:
			print "%sinvalid tag database line '%s'" % (logHeader(), line.strip())
		print "%sinvalid tag database: exiting" % (logHeader(),)
		sys.exit(2)
		
	return tagsDict


# sqlite has no column removal in alter table; can only add columns
# so instead we create new tag table and replace old
def createNewTagTable(taxDatabase):
	with sqlite3.connect(taxDatabase) as conn:
		conn.execute("DROP TABLE IF EXISTS new_tags")
		# COLLATE NOCASE makes string matching case-insensitive
		conn.execute("CREATE TABLE new_tags (taxid INTEGER PRIMARY KEY, %s)"
				% (', '.join(["%s TEXT" % cat for cat in TaxonTag.categories])))


def populateTagsUsingPython(taxDatabase, tagsDict):
	# Since we tag the taxonomy nodes explicitly, each tag value applies
	# to exactly one taxid. Use this to validate the tag file.
	# tagsDict does not contain empty tag values so much specify insert
	# columns for each row inserted.
	delimiter = ','
	validTagsDict = {}
	with sqlite3.connect(taxDatabase) as conn:
		conn.row_factory = sqlite3.Row
		for row in conn.execute("SELECT names.taxid, name, rank FROM names, nodes WHERE names.taxid = nodes.taxid"):
			key = (row["name"], row["rank"])
			ttag = tagsDict.pop(key, None)
			if ttag is None:
				continue

			validTagsDict[key] = ttag
			if cmd != 'load':
				continue

			# ttag is an instance of TaxonTag
			values = ["'%s'" % ttag.tagDict[cat] for cat in TaxonTag.categories]
			conn.execute("INSERT INTO new_tags (taxid, %s) VALUES (%s, %s)" 
					% (delimiter.join(TaxonTag.categories), row["taxid"], delimiter.join(values)))

	return validTagsDict


# This way of matching leaves open the possibility of case-insensitive matching
# or using LIKE % but for now Samia says use exact match.
# Note that NCBI taxonomy nodes are almost always unique but not always, e.g., 
# 78589 and 610258 are both genus "Geomyces" but from different classes!
def populateTagsUsingSQL(taxDatabase, tagsDict):
	# Since we tag the taxonomy nodes explicitly, each tag value applies
	# to exactly one taxid. Use this to validate the tag file.
	# tagsDict does not contain empty tag values so much specify insert
	# columns for each row inserted.
	delimiter = ','
	validTagsDict = {}
	with sqlite3.connect(taxDatabase) as conn:
		conn.row_factory = sqlite3.Row
		for key in tagsDict.keys():
			name, rank = key
			rows = conn.execute("SELECT names.taxid, name, rank FROM names, nodes WHERE names.taxid = nodes.taxid AND name = ? AND rank = ?", (name, rank))
			rowlist = list(rows) # destroys cursor
			if len(rowlist) > 1:
				print "%sambiguous name %s, rank %s matches multiple tax IDs %s: skipping" % (logHeader(), rank, name, ", ".join([str(row[0]) for row in rowlist]))
				continue

			# second query required to obtain cursor
			for row in conn.execute("SELECT names.taxid, name, rank FROM names, nodes WHERE names.taxid = nodes.taxid AND name = ? AND rank = ?", (name, rank)):
				# tags is a dict {category: value,...}
				ttag = tagsDict.pop(key)
				validTagsDict[key] = ttag
				if cmd != 'load':
					continue

				values = ["'%s'" % ttag.tagDict.get(cat, "") for cat in TaxonTag.categories]
				conn.execute("INSERT INTO new_tags (taxid, %s) VALUES (%s, %s)" 
						% (delimiter.join(TaxonTag.categories), row["taxid"], delimiter.join(values)))

	return validTagsDict


def renameTagTable(taxDatabase):
	with sqlite3.connect(taxDatabase) as conn:
		conn.execute("DROP TABLE IF EXISTS tags")
		conn.execute("ALTER TABLE new_tags RENAME TO tags")


def logUnappliedTags(tagsDict):
	for key, ttag in tagsDict.iteritems():
		name, rank = key
		tags = ["%s: %s" % (cat, ttag.tagDict[cat]) for cat in TaxonTag.categories if cat in ttag.tagDict]
		print "%sunapplied tags: %s %s: %s" % (logHeader(), rank, name, "; ".join(tags))


# searchTaxonomy examines one column in the lookup table (family, genus, or species) using LIKE,
# i.e., a case-insensitive search. If the '-partial' option is false, then a whole word filter
# is applied.
def searchTaxonomy(taxDatabase, tagCat, tagValue, searchRank, keywords):
	# tagsDict = {(name, rank): TaxonTag object}
	tagsDict = {}
	
	with sqlite3.connect(taxDatabase) as conn:
		conn.row_factory = sqlite3.Row
		for keyword in keywords:
			# conservative default requires whole words, which we determine via regexp
			reWord = re.compile(r'\b%s\b' % keyword, re.I)

			# SQL statement will return partial word matches
			for row in conn.execute("SELECT species, genus, family FROM lookup WHERE %s LIKE ?" % searchRank, ("%%%s%%" % keyword,)):
				if not partial and reWord.search(row[searchRank]) is None:
					print "%s%s not a whole word in %s" % (logHeader(), keyword, row[searchRank])
					continue

				print "%s%s found %s" % (logHeader(), keyword, row[searchRank])
				tagsDict[(row[searchRank], searchRank)] = TaxonTag((row["family"], row["genus"], row["species"]), {tagCat: tagValue})

	if tagsDict:
		TaxonTag.setRanks(RANKS)
		TaxonTag.setCategories([tagCat])
	return tagsDict


# searchLineage is a special case of searching taxonomy. We examine the entire lineage string
# then look down the lineage taxa of family, genus, or species to include as results.
# A complicating factor: Once a genus is tagged, its species should not be tagged; once a family
# is tagged, it genera and species should not be tagged.
# A further complication is that some names are found in at different taxonomic ranks along
# a single lineage so we have to verify rank.
def searchLineage(taxDatabase, tagCat, tagValue, keywords):
	# tagsDict = {(name, rank): TaxonTag object}
	tagsDict = {}
	
	with sqlite3.connect(taxDatabase) as conn:
		conn.row_factory = sqlite3.Row
		for keyword in keywords:
			# conservative default requires whole words, which we determine via regexp
			reWord = re.compile(r'\b%s\b' % keyword, re.I)

			# SQL statement will return partial word matches
			for row in conn.execute("SELECT rank, family, genus, species, lineage FROM lookup WHERE lineage LIKE ? ORDER BY family, genus, species", ("%%%s%%" % keyword,)):

				if not partial and reWord.search(row["lineage"]) is None:
					print "%s%s not a whole word in %s" % (logHeader(), keyword, row["lineage"])
					continue
				print "%s%s found %s" % (logHeader(), keyword, row["lineage"])

				foundTaxon = False
				for taxon in row["lineage"].split(';'):
					if not foundTaxon:
						if keyword not in taxon or (not partial and reWord.search(taxon) is None):
							continue
					foundTaxon = True

					if (row["family"], "family") in tagsDict:
						# this lineage is already captured at the family level
						break

					if row["rank"] == "family" and taxon == row["family"]:
						# we have a bona fide family match so add it and move on
						tagsDict[(row["family"], "family")] = TaxonTag((row["family"], "", ""), {tagCat: tagValue})
						break

					if (row["genus"], "genus") in tagsDict:
						# this lineage is already captured at the genus level
						break

					if row["rank"] == "genus" and taxon == row["genus"]:
						# we have a bona fide genus match so add it and move on
						tagsDict[(row["genus"], "genus")] = TaxonTag((row["family"], row["genus"], ""), {tagCat: tagValue})
						break

					if (row["species"], "species") in tagsDict:
						# this lineage is already captured at the species level
						break

					if row["rank"] == "species" and taxon == row["species"]:
						# we have a bona fide species match so add it and move on
						tagsDict[(row["species"], "species")] = TaxonTag((row["family"], row["genus"], row["species"]), {tagCat: tagValue})
						break

	if tagsDict:
		TaxonTag.setRanks(RANKS)
		TaxonTag.setCategories([tagCat])
	return tagsDict


# collate updates t1 with the contents of t2 and returns a new dictionary, i.e., we always
# return full contents of t1.
# t2 is a search result and always contains a single tag category
# key = (name, rank)
# Conditions can vary for each row:
#   - t1 key might not exist in t2
#   - t1 key might exist in t2
#   Within each row for each tag category:
#     - t2 category might be new to t1
#     - t2 category might exist in t1
#       - t2 value might be new to t1
#       - t2 value might exist in t1
def collate(t1, t2, tagCat, tagValue):
	# tagsDict = {(name, rank): TaxonTag()}
	tagsDict = {}

	# copy t1 so we can modify parts freely
	for key, tt1 in t1.items():
		tagsDict[key] = tt1
		if key not in t2:
			continue
		else:
			tt2 = t2.pop(key)
			# for a single row
			for tagCat in tt2.tagDict:
				# blank cells in file are not stored in t1
				if tagCat not in tt1.tagDict:
					tt1.tagDict[tagCat] = tt2.tagDict[tagCat]

				else: # t2 category & value exists in t1
					name, rank = key
					print "%s%s %s found existing %s value '%s': dropping '%s'" % (logHeader(), rank, name, tagCat, tt1.tagDict[tagCat], tt2.tagDict[tagCat])

	# what's left is new to t1
	for key in t2:
		tagsDict[key] = t2[key]

	return tagsDict


def writeTags(tagFile, tagsDict, outFile):
	print "%swriting to %s" % (logHeader(), outFile)

	with open(outFile, 'w') as f:
		print >> f, "%s\t%s" % ('\t'.join(TaxonTag.ranks), '\t'.join(TaxonTag.categories))
		for tt in sorted(tagsDict.values(), key=operator.attrgetter('taxa')):
			print >> f, "%s\t%s" % ('\t'.join(tt.taxa), '\t'.join([tt.tagDict.get(cat, "") for cat in TaxonTag.categories]))


#
### Commands
#

### Clean command removes redundant rows from a tagging file.
def clean(tagFile):
	# tagsDict = {(name, rank): TaxonTag()}
	print "%sbegin cleaning tag file %s" % (logHeader(), tagFile)

	tagsDict = readTagFile(tagFile)
	count = len(tagsDict)
	cleanDict = {}
	for key in tagsDict:
		# key comes from most specific taxa in a row
		name, rank = key # e.g., Homo sapiens, species
		# tt represents one row in a tagging file
		tt = tagsDict[key]

		# only first non-blank higher rank is capable of eliminating this row
		# traverse from species up the tree
		start = False
		drop = False
		for i in range(len(tt.ranks)-1, -1, -1):
			# tt.ranks are currently 'family', 'genus', 'species'
			# so we are iterating species, genus, family
			r = tt.ranks[i]
			if not start and r == rank:
				start = True
				continue

			# make key from current taxa column
			n = tt.taxa[i]
			k = (n, r)
			if k not in tagsDict:
				# higher one might still exist
				continue

			# drop this row only if tags are identical
			if tagsDict[k].tagDict == tt.tagDict:
				# this entry renders the old one superfluous so we won't include it
				print "%s%s %s entry supersedes %s %s; dropping %s" % (logHeader(), r, n, rank, name, rank)
				drop = True
			
			break

		if not drop:
			cleanDict[key] = tt

	removed = count - len(cleanDict)
	print "%sremoved %d rows" % (logHeader(), removed)

	if removed:
		outFile = "%s.clean" % (tagFile,)
		writeTags(tagFile, cleanDict, outFile)
	else:
		print "%s%s already clean" % (logHeader(), tagFile)


### Load command loads a tags database table from a tagging file.
def load(tagFile, taxDatabase):
	print "%sbegin tagging taxonomy database %s" % (logHeader(), taxDatabase)
	print "%sreading tag file %s" % (logHeader(), tagFile)
	tagsDict = readTagFile(tagFile)

	print "%sassigning tags" % (logHeader(),)
	createNewTagTable(taxDatabase)
	#populateTagsUsingPython(taxDatabase, tagsDict)
	populateTagsUsingSQL(taxDatabase, tagsDict)
	renameTagTable(taxDatabase)
	if tagsDict:
		print "%snot all tags were assigned" % (logHeader(),)
		logUnappliedTags(tagsDict)
	else:
		print "%sall tags were assigned!" % (logHeader(),)


### Search command searches a taxonomy database for specified text.
def search(tagFile, taxDatabase, tagCat, tagValue, searchRank, keywords):
	# read existing file first so it's category columns are first in collated file
	if tagFile:
		oldTagsDict = readTagFile(tagFile)

	if searchRank == 'lineage':
		tagsDict = searchLineage(taxDatabase, tagCat, tagValue, keywords)
	else:
		tagsDict = searchTaxonomy(taxDatabase, tagCat, tagValue, searchRank, keywords)
	if not tagsDict:
		print "%sno %s found for %s %s using %s" % (logHeader(), searchRank, tagCat, tagValue, ', '.join(keywords))
		return

	newCount = len(tagsDict)
	if tagFile:
		tagsDict = collate(oldTagsDict, tagsDict, tagCat, tagValue)
		newCount = len(tagsDict) - len(oldTagsDict)
		if not newCount:
			print "%sno %s new to %s found for %s %s using %s" % (logHeader(), searchRank, tagFile, tagCat, tagValue, ', '.join(keywords))
			return

	print "%sfound %d new %s for %s %s using %s" % (logHeader(), newCount, searchRank, tagCat, tagValue, ', '.join(keywords))

	tagCat = tagCat.replace(' ', '_')
	tagValue = tagValue.replace(' ', '_')
	if not tagFile:
		outFile = os.path.join(outDir, "tagging.%s-%s" % (tagCat, tagValue))
	else:
		outFile = "%s.%s-%s" % (tagFile, tagCat, tagValue)
	writeTags(tagFile, tagsDict, outFile)


### Validate command validates content of a tagging file.
def validate(tagFile, taxDatabase):
	print "%sbegin validating tag file %s" % (logHeader(), tagFile)
	print "%sreading tag file %s" % (logHeader(), tagFile)
	tagsDict = readTagFile(tagFile)
	validTagsDict = populateTagsUsingSQL(taxDatabase, tagsDict)
	if tagsDict:
		print "%snot all tags were assignable" % (logHeader(),)
		logUnappliedTags(tagsDict)
		if dropInvalid:
			outFile = "%s.valid" % tagFile
			writeTags(tagFile, validTagsDict, outFile)
	else:
		print "%sall tags were assignable!" % (logHeader(),)
	print "%svalidation complete" % (logHeader(),)


def checkFile(fileName, fileDesc):
	if fileName is None:
		usage("%s not specified" % (fileDesc,))
		sys.exit(2)
	if not os.path.exists(fileName):
		usage("%s not found: %s" % (fileDesc, fileName))
		sys.exit(2)


def check(value, desc):
	if not value:
		usage("%s not specified" % desc)
		sys.exit(2)


def usage(msg=None):
	print "Usage: %s <validate|clean|search|load> [--partial] [--taxdb=<taxonomy database file>] [--tagfile=<file path>] [--tagcat=<tag category>] [--tagvalue=<tag value>] [--rank=<search rank>] [[--keyword=<keyword>]...]" % sys.argv[0]
	print
	print "  Commands:"
	print "  	clean: remove logically redundant rows from a tagging file, e.g., species tags under a genus tag"
	print "  		requires tagfile; taxonomy database not modified"
	print "  	validate: remove nonfunctional tags, i.e., those with no corresponding taxon ID"
	print "  		requires tagfile, taxdb; taxonomy database not modified"
	print "  	search: search a taxonomy database for nodes containing keywords: taxonomy database not modified"
	print "  		requires taxdb, tagcat, tagvalue, rank, one or more keywords; tagfile is optional"
	print "  	load: load a tags database table from a tagging file"
	print "  		requires tagfile, taxdb"
	print
	print "  Options:"
	print "  	--outdir: destination of new search output file"
	print "  	--partial: extend search to partial words (default searches whole words only)"
	print "  	--dropinvalid: create new file without invalid rows (default leaves file unchanged)"
	print "  	--taxdb: path to reference taxonomy database file"
	print "  	--tagfile: tag file to validate or to add tags"
	print "  	--tagcat: tag category, e.g., host"
	print "  	--tagvalue: tag value, e.g., bacteria"
	print "  	--rank: the taxonomy rank to search (%s)" % ', '.join(searchRanks)
	print "  	--keyword: word or text to search for"
	print
	print "A complete workflow, with the output of each command serving as the input of the next:"
	print "    clean the current tag file to reduce size"
	print "    validate the cleaned file to remove nonfunctional tags"
	print "    search for new tags"
	print "    load the new tag file back into the taxonomy database"
	print
	print "  Note this program may alter the taxonomy database schema and is idempotent."
	if msg:
		print msg


if __name__ == '__main__':
	import getopt
	cmd = None
	outDir = ""
	partial = False
	dropInvalid = False
	taxDatabase = tagFile = tagCat = tagValue = None
	searchRank = None
	searchRanks = set(['species', 'genus', 'family', 'lineage'])
	keywords = set()

	commands = set(['validate', 'clean', 'search', 'load'])
	try:
		cmd = sys.argv[1]
	except IndexError:
		usage("must specify a command")
		sys.exit(2)
	if cmd not in commands:
		usage("unknown command '%s'" % cmd)
		sys.exit(2)

	try:
		options, args = getopt.getopt(sys.argv[2:], "", ["outdir=", "partial", "dropinvalid", "taxdb=", "tagfile=", "tagcat=", "tagvalue=", "rank=", "keyword="])
		for option, value in options:
			if option == '--outdir':
				outDir = value
				checkFile(outDir, 'output directory')
			elif option == '--partial':
				partial = True
			elif option == '--dropinvalid':
				dropInvalid = True
			elif option == '--taxdb':
				taxDatabase = value
				checkFile(taxDatabase, 'taxonomy database file')
			elif option == '--tagfile':
				tagFile = value
				checkFile(tagFile, 'tag file')
			elif option == '--tagcat':
				tagCat = value
			elif option == '--tagvalue':
				tagValue = value
			elif option == '--rank':
				searchRank = value
				if searchRank not in searchRanks:
					usage("%s not a searchable rank" % searchRank)
					sys.exit(2)
			elif option == '--keyword':
				keywords.add(value)
	except getopt.GetoptError, msg:
		usage(msg)
		sys.exit(2)

	if cmd == 'clean':
		checkFile(tagFile, 'tag file')
		clean(tagFile)

	elif cmd == 'load':
		checkFile(tagFile, 'tag file')
		checkFile(taxDatabase, 'taxonomy database file')
		load(tagFile, taxDatabase)

	elif cmd == 'search':
		# tagFile is not required
		checkFile(taxDatabase, 'taxonomy database file')
		check(tagCat, 'tag category')
		check(tagValue, 'tag value')
		check(searchRank, 'search rank (i.e., one of %s)' % ', '.join(searchRanks))
		check(keywords, 'keyword')
		search(tagFile, taxDatabase, tagCat, tagValue, searchRank, keywords)

	elif cmd == 'validate':
		checkFile(tagFile, 'tag file')
		checkFile(taxDatabase, 'taxonomy database file')
		validate(tagFile, taxDatabase)

	else:
		print "%sdid nothing" % logHeader()

