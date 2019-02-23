import os

COMMA = ','
HEADER = '[Header]'
DATA = '[Data]'
INDEX = 'index'
INDEX2 = 'index2'
SECTIONS = set([HEADER, '[Reads]', '[Settings]', DATA])

class SampleSheet(object):
	"""Sample sheet data."""

	def __init__(self):
		# simple dictionary of labels and values
		self.header = {}
		# Organized by column label, then full barcode.
		self.data = {}

	def read(self, f):
		lines = f.readlines()
		sectionName = None
		sectionLines = []
		for line in lines:
			line = line.strip()
			if not line:
				continue

			cols = line.split(COMMA)
			if cols[0] in SECTIONS:
				if sectionLines:
					self.readSection(sectionName, sectionLines)
				sectionName = cols[0]
				sectionLines = []
				continue
			sectionLines.append(line)
		# pick up the final section
		if sectionLines:
			self.readSection(sectionName, sectionLines)

	def readSection(self, name, lines):
		if name == HEADER:
			self.readHeader(lines)
		elif name == DATA:
			self.readData(lines)

	def readHeader(self, lines):
		assert not self.header
		for line in lines:
			cols = line.split(COMMA)
			if not cols[0]:
				continue
			self.header[normalize(cols[0])] = cols[1]

	# Organize data by column label, then by full barcode.
	def readData(self, lines):
		assert not self.data
		labels = []
		for line in lines:
			cols = line.split(COMMA)
			if not (cols[0] or cols[1]):
				continue

			# collect the labels
			if not labels:
				for i, col in enumerate(cols):
					if not col.strip():
						continue
					labels.append((i, col))
				continue

			# transpose the data to get desired organization
			# first build the full barcode for the row
			lineData = {}
			for i, label in labels:
				lineData[label] = cols[i]
			if lineData[INDEX2]:
				barcode = "%s+%s" % (lineData[INDEX], lineData[INDEX2])
			else:
				barcode = "%s" % (lineData[INDEX],)
			# organize the data
			for label in lineData:
				dataDict = self.data.setdefault(normalize(label), {})
				dataDict[barcode] = lineData[label]


def normalize(label):
	return label.strip().lower().replace(' ', '_')


# readV2 reads the file at path and returns dict of barcodes to sample
# objects. If the file does not exist an empty dict is returned.
def readV2(fileName):
	with open(fileName, 'rU') as f:
		ss = SampleSheet()
		ss.read(f)
	return ss


# readV1 reads the file at path and returns dict of barcodes to sample.
# Assumes a mandatory set of column headings: Barcode, Sample, and
# optionally Description. 
def readV1(fileName):
	sampleDict = {}
	if fileName is None:
		return sampleDict

	with open(fileName, 'rU') as f:
		firstLine = True
		for line in f:
			parts = line.split()
			if len(parts) < 2:
				continue
			if firstLine:
				if parts[0] == 'Barcode':
					firstLine = False
					continue
				else:
					print "%ssample sheet '%s' has unexpected format" % (
							logHeader(), fileName)
					return sampleDict

			# map barcode to sample
			sampleDict[parts[0]] = parts[1]
	return sampleDict

