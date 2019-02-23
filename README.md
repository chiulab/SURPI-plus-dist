
Copyright Notice

Copyright (c) 2014, 2015 Regents of the University of California

All rights reserved.

Regents of the University of California are the proprietor of the copyrights of and to the SURPI+ software ("Software"). Redistribution and use of the Software with or without modification are permitted provided that redistributions of Software must retain the above copyright notice, list of conditions and the following disclaimer.

a)	Use of the Software for the sale of any product or service or for the purpose of profit-making or patient care is strictly prohibited. Use of the Software is allowed for research purposes only.

b)	Any request to furnish all or any portion of the Software for the sale of any product or service or for the purpose of profit-making or patient care, shall be in writing to Executive Director of Technology Management, Innovation Ventures, the University of California, San Francisco.

c)	The Software uses third party resources listed below in i, ii, iii, iv, v, vi, vii, viii and ix ("Third Party Resources"). Certain licenses attach to Third Party Resources and by using Software you agree to abide by those licenses.

i.	NCBI Blast suite v2.7.1

Link: http://blast.ncbi.nlm.nih.gov/Blast.cgi

ii.	Bowtie2 v2.3.2

Link: http://bowtie-bio.sourceforge.net/bowtie2/index.shtml

iii.	cutadapt v.1.9.1-1build1

Link: https://cutadapt.readthedocs.io/en/stable/

iv.	fastQValidator v1.0.14

Link: https://github.com/statgen/fastQValidator

v.	gt v.1.5.9

Link: http://genometools.org

vi.	PRINSEQ-lite v0.20.4

Link: http://prinseq.sourceforge.net

vii.	seqtk v1.3

Link: https://github.com/lh3/seqtk

viii. 	SNAP v1.0dev100

Link: http://snap.cs.berkeley.edu/

ix. 	vmtouch v1.3.1

Link: https://github.com/hoytech/vmtouch

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANT ABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


## Hardware & Software Requirements

- Linux server, tested Ubuntu 16.04 with 512 GB memory, 5 TB disk volume
- Singularity (https://www.sylabs.io), tested v2.5.2

## Getting started

1. Configure a server
2. Make the SURPI container image
3. Build the reference dataset
4. Download example fastq file from NCBI
5. Run SURPI on the fastq file
6. Examine results as `.annotated` and/or `.counttable` files

## Instructions for making SURPI container

Clone the GitHub repository and create the Singularity image file:
```
git clone https://github.com/chiulab/SURPI-plus-dist.git SURPI
cp SURPI/etc/singularity/Makefile .
sudo make SURPI.sqsh
```

## Instructions for building reference data

- mkdir `<reference folder>`
- cd `<reference folder>`
- REFERENCE="`<reference folder path>`"
- IMAGE="`<SURPI container image path>`"
```
singularity exec --app SURPI --bind ${REFERENCE} ${IMAGE} bash -c "cp -r /scif/apps/SURPI/SURPI/etc/reference/* ${REFERENCE}"
singularity exec --app SURPI --bind ${REFERENCE} ${IMAGE} bash -c "make -C ${REFERENCE} all"
```

NOTE: Temporary directory usage will be hight. Set and export `TMPDIR` environment variable as needed and include in Singularity bind mounts.

## Instructions for running SURPI container

- mkdir `<run folder>`
- cp `<fastq file>` `<run folder>`
- cd `<run folder>`
- REFERENCE="`<reference folder path>`"
- RUN="`<run folder path>`"
- IMAGE="`<SURPI container image path>`"
```
singularity run --bind "${REFERENCE},${RUN}" --app SURPI ${IMAGE} -z <fastq file>
singularity run --bind "${REFERENCE},${RUN}" --app SURPI ${IMAGE} -f <run config>
```
NOTE: Singularity bind mounts must encompass temporary directory in config file (/tmp is default mount).
