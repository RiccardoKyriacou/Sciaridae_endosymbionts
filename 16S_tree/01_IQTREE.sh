#!/bin/bash -l

#SBATCH --job-name=IQTREE
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32gb
#SBATCH --time=3-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --output=IQTREE.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -e

hostname
date

source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/genomics
############################################################
# Setup
############################################################
SCRATCH=/scratch/${USER}/IQTREE.${SLURM_JOB_ID}
OUTDIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project/16S_tree/outputs/all_16s_tree
mkdir -p $SCRATCH
cd $SCRATCH

rsync -av $OUTDIR/ALL_16S_bacteria_SILVAreference.fasta $SCRATCH

FASTA="ALL_16S_bacteria_SILVAreference.fasta"

############################################################
# STEP  1 - Filter for < 1200bp 
############################################################
seqkit seq -m 1200 $FASTA > ALL_16S_filtered.fasta

############################################################
# STEP  2 - Multiple sequence alignment 
############################################################
mafft --auto ALL_16S_filtered.fasta > ALL_16S_filtered.mafft.fasta

############################################################
# STEP  3 - Trim
############################################################
trimal -in ALL_16S_filtered.mafft.fasta\
       -out ALL_16S_filtered.mafft.trimal.fasta \
       -automated1

############################################################
# STEP  4 - IQtree
############################################################
iqtree \
  -s ALL_16S_filtered.mafft.trimal.fasta \
  -m MFP \
  -B 1000 \
  -alrt 1000 \
  -T 16 \
  -seed 33 \

############################################################
# Finish and clean
############################################################
rsync -av * $OUTDIR

echo "Cleaning scratch..."
rm -rf $SCRATCH
echo "done"
