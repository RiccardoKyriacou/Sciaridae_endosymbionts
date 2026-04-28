#!/bin/bash -l

#SBATCH --job-name=hifiasm_16S_Ling
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=120gb
#SBATCH --time=3-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --output=hifiasm_16S_Ling.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -e

hostname
date

############################################################
# Setup
############################################################

SPECIES="L_ingenua"
BASE_DIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project

WORKDIR=${BASE_DIR}/${SPECIES}/outputs/Hifiasm
SCRATCH=/scratch/${USER}/hifiasm.${SLURM_JOB_ID}

mkdir -p $WORKDIR
mkdir -p $SCRATCH
cd $SCRATCH

############################################################
# Load conda
############################################################

source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/genomics

############################################################
# STEP 1 — Download
############################################################
echo "Downloading PacBio reads..."

SRR=(
    ERR15170267
)

for SAMPLE in "${SRR[@]}"; do
    echo "Downloading $SAMPLE"
    prefetch $SAMPLE
    fasterq-dump $SAMPLE -e 16
done

############################################################
# STEP 2 — Combine
############################################################
echo "Combining reads..."
pigz *.fastq
cat *.fastq.gz > combined.fastq.gz

############################################################
# STEP 3 — Assemble
############################################################
echo "Running hifiasm..."
hifiasm --primary -o ${SPECIES}.asm -t 32 combined.fastq.gz

############################################################
# STEP 4 — Convert
############################################################
awk '$1 == "S" {print ">"$2"\n"$3}' \
    ${SPECIES}.asm.p_ctg.gfa > ${SPECIES}_p_ctg.fa

############################################################
# STEP 5 — Extract 16S
############################################################
echo "Running barrnap..."
barrnap --kingdom bac \
    --threads 8 \
    --outseq ${SPECIES}_16S.fasta \
    ${SPECIES}_p_ctg.fa > ${SPECIES}_16S.gff

############################################################
# STEP 6 — Save
############################################################
echo "Saving outputs..."

rsync -av ${SPECIES}_p_ctg.fa $WORKDIR/
rsync -av ${SPECIES}_16S.fasta $WORKDIR/
rsync -av ${SPECIES}_16S.gff $WORKDIR/

############################################################
# Cleanup
############################################################
rm -rf $SCRATCH

echo "done."
date
