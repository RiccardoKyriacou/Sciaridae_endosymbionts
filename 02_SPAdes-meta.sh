#!/bin/bash -l

#SBATCH --job-name=spades-meta
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=500gb
#SBATCH --export=ALL
#SBATCH --time=10-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --output=spades-meta.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -euo pipefail
hostname
date

# Load conda
source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/genomics

BASE_DIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project

declare -A SAMPLES=(
    [B_confinis]=SRR29039101
    [L_agraria]=SRR29039068
    [B_pectoralis]=SRR29039103
    [B_desolata]=SRR29039102
)

for SPECIES in "${!SAMPLES[@]}"; do
    echo "=========================================="
    echo "   ${SPECIES}"
    echo "=========================================="

    FASTQ_DIR=${BASE_DIR}/${SPECIES}/outputs/fastq
    OUTDIR=${BASE_DIR}/${SPECIES}/outputs/spades_meta
    SCRATCH=/scratch/${USER}/spades.${SLURM_JOB_ID}/${SPECIES}

    mkdir -p "$SCRATCH"
    cd "$SCRATCH"

    # Copy FASTQs to scratch
    rsync -av ${FASTQ_DIR}/*_*.fastq.gz "$SCRATCH/"

    # Identify R1/R2 on scratch
    R1=$(ls "$SCRATCH"/*_1.fastq.gz)
    R2=$(ls "$SCRATCH"/*_2.fastq.gz)
    base=$(basename "$R1" "_1.fastq.gz")

    ####################################################
    # Trim reads with fastp
    ####################################################
    fastp \
        -i "$R1" -I "$R2" \
        -o "${base}_R1.trimmed.fastq.gz" \
        -O "${base}_R2.trimmed.fastq.gz" \
        -w 16 

    # Remove raw reads to save space
    rm "$R1" "$R2"

    ####################################################
    # Downsample trimmed reads to 50%
    ####################################################
    echo "Downsampling trimmed reads to 50%..."

    seqtk sample -s100 "${base}_R1.trimmed.fastq.gz" 0.1 | gzip > "${base}_R1.sub.fastq.gz"
    seqtk sample -s100 "${base}_R2.trimmed.fastq.gz" 0.1 | gzip > "${base}_R2.sub.fastq.gz"

    # Remove full trimmed reads to save scratch space
    rm "${base}_R1.trimmed.fastq.gz" "${base}_R2.trimmed.fastq.gz"

    ####################################################
    # Run SPAdes meta-assembly on downsampled reads
    ####################################################
    echo "Running SPAdes meta-assembly for ${SPECIES}"

    spades.py \
        --meta \
        -t 8 \
        -m 500 \
        -1 "${base}_R1.sub.fastq.gz" \
        -2 "${base}_R2.sub.fastq.gz" \
        -o "$SCRATCH/spades_output"

    ####################################################
    # Filter contigs ≥1000 bp
    ####################################################
    mkdir -p "$OUTDIR"

    seqkit seq -m 1000 \
        "${SCRATCH}/spades_output/contigs.fasta" \
        > "${OUTDIR}/contigs.min1000bp.fasta"

    seqkit stats "${OUTDIR}/contigs.min1000bp.fasta"

    # Sync SPAdes outputs back
    rsync -av "$SCRATCH/spades_output/" "$OUTDIR/"

    # Clean scratch
    rm -rf "$SCRATCH"

    echo "Finished SPAdes + contig filtering for ${SPECIES}"
done

echo "All SPAdes meta assemblies complete."
