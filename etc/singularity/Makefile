# build SURPI image

.PHONY: run debug shell

SURPI.sqsh: SURPI/etc/singularity/SURPI.def SURPI_base.sqsh SURPI/.git
	rm -rf SURPI.sqsh
	singularity build SURPI.sqsh SURPI/etc/singularity/SURPI.def

SURPI_base.sqsh: SURPI/etc/singularity/SURPI_base.def
	rm -f SURPI_base.sqsh
	singularity build SURPI_base.sqsh SURPI/etc/singularity/SURPI_base.def

