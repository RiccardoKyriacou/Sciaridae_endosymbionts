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

############################################################
# Paths
############################################################

BASE_DIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project
SILVA_DB=/mnt/loki/db/SILVA-138.1/138.1

############################################################
# Samples
############################################################

declare -A SAMPLES=(
    [B_confinis]=SRR29039101
    [L_agraria]=SRR29039068
    [B_pectoralis]=SRR29039103
    [B_desolata]=SRR29039102
    [T_splendens]=SRR5218407
    [P_flavipes]=SRR5217995
    [P_flavipes]=SRR18645815
)

############################################################
# Loop through samples
############################################################

for SPECIES in "${!SAMPLES[@]}"; do

    source /home/s2673271/miniforge3/etc/profile.d/conda.sh
    conda activate /home/s2673271/miniforge3/envs/genomics

    echo "=========================================="
    echo "Processing: ${SPECIES}"
    echo "=========================================="

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

    R1=$(ls *_1.fastq.gz)
    R2=$(ls *_2.fastq.gz)

    base=$(basename "$R1" "_1.fastq.gz")

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
        -w 8 \
        -h fastp_report.html \
        -j fastp_report.json

    rm "$R1" "$R2"

    ########################################################
    # Run phyloFlash
    ########################################################

    echo "Running phyloFlash..."

    source /home/s2673271/miniforge3/etc/profile.d/conda.sh
    conda activate /home/s2673271/miniforge3/envs/pf

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

done

echo "=========================================="
echo "All phyloFlash runs complete."
echo "=========================================="

date