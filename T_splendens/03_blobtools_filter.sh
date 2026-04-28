#!/bin/bash -l

#SBATCH --job-name=blobtools2_filter
#SBATCH --nodes=1
#SBATCH --ntasks=32
#SBATCH --export=ALL
#SBATCH --time=3-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --mem=32gb
#SBATCH --output=blobtools2_filter.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -e
source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/blobtools2

###############################################################
# Paths
###############################################################
OUTDIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project/T_splendens/outputs/blobtools
mkdir -p $OUTDIR

BLOBDIR="${OUTDIR}/Tspl_blobdir"
ASM="/mnt/loki/ross/flies/sciaridae/endosymbiont_project/T_splendens/outputs/spades_meta/contigs.min1kb.fasta "

###############################################################
# Pseudomonadota
###############################################################
TAXON=Pseudomonadota

blobtools filter \
  --invert \
  --param bestsumorder_phylum--Keys=$TAXON \
  --fasta ${ASM} \
  --output ${OUTDIR}/${TAXON}_blobdir \
  --suffix ${TAXON} \
  $BLOBDIR

####################################################################################
# Mycoplasmatota
####################################################################################
TAXON=Mycoplasmatota

blobtools filter \
  --invert \
  --param bestsumorder_phylum--Keys=$TAXON \
  --fasta ${ASM} \
  --output ${OUTDIR}/${TAXON}blobdir \
  --suffix ${TAXON}\
  $BLOBDIR

###############################################################
# Pseudomonadota
###############################################################
TAXON=Bacillota

blobtools filter \
  --invert \
  --param bestsumorder_phylum--Keys=$TAXON \
  --fasta ${ASM} \
  --output ${OUTDIR}/${TAXON}_blobdir \
  --suffix ${TAXON} \
  $BLOBDIR

echo "Filtering complete. Temporary files removed."
