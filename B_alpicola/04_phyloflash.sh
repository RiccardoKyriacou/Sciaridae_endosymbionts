#!/bin/bash -l

#SBATCH --job-name=phyloflash_ssu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=200gb
#SBATCH --time=5-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --output=phyloflash.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -e

hostname
date

source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/genomics

############################################################
# Paths
############################################################
BASE_DIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project
SILVA_DB=/mnt/loki/db/SILVA-138.1/138.1

SPECIES=B_alpicola

FASTQ_DIR=${BASE_DIR}/${SPECIES}/outputs/fastq
OUTDIR=${BASE_DIR}/${SPECIES}/outputs/phyloFlash
SCRATCH=/scratch/${USER}/phyloflash.${SLURM_JOB_ID}/${SPECIES}
mkdir -p "$SCRATCH"
mkdir -p "$OUTDIR"
cd "$SCRATCH"

########################################################
# Copy reads to scratch
########################################################
echo "Copying FASTQ files to scratch..."
rsync -av ${FASTQ_DIR}/*_*.fastq.gz .
########################################################
# Detect paired reads
########################################################
R1=$(ls *1.fastq.gz)
R2=$(ls *2.fastq.gz)
base=$(basename "$R1" "_R1.fastq.gz")
echo "R1: $R1"
echo "R2: $R2"

########################################################
# Trim reads
########################################################
echo "Running fastp..."

fastp \
    -i "$R1" \
    -I "$R2" \
    -o "${base}_R1.trimmed.fastq.gz" \
    -O "${base}_R2.trimmed.fastq.gz" \
    -w $SLURM_CPUS_PER_TASK \
    -h fastp_report.html \
    -j fastp_report.json
rm "$R1" "$R2"

########################################################
# Run phyloFlash
########################################################
echo "Running phyloFlash..."

source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/pf

export TERM=xterm    

phyloFlash.pl \
    -lib ${SPECIES} \
    -read1 "${base}_R1.trimmed.fastq.gz" \
    -read2 "${base}_R2.trimmed.fastq.gz" \
    -dbhome ${SILVA_DB} \
    -CPUs $SLURM_CPUS_PER_TASK \
    -readlength 150 \
    -almosteverything \
    -log  # can try --everything if need better asms
########################################################
# Sync results
########################################################
echo "Syncing results..."
rsync -av *.phyloFlash* "$OUTDIR/"
rsync -av fastp_report.* "$OUTDIR/"

########################################################
# Cleanup
########################################################
echo "Cleaning scratch..."
rm -rf "$SCRATCH"
echo "Finished ${SPECIES}"
echo ""

date
