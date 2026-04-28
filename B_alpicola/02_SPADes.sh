#!/bin/bash -l

#SBATCH --job-name=SPAdes
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128gb
#SBATCH --export=ALL
#SBATCH --time=3-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --output=SPAdes.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

hostname
set -e

source /home/s2673271/miniforge3/etc/profile.d/conda.sh     
conda activate /home/s2673271/miniforge3/envs/genomics

SCRATCH=/scratch/${USER}/spades.${SLURM_JOB_ID}
mkdir -p "$SCRATCH"
cd "$SCRATCH"

#######################################
# Stage to scratch 
#######################################
rsync -av \
  /mnt/loki/ross/flies/sciaridae/endosymbiont_project/B_alpicola/outputs/fastq/B_alp_combined_R*.fastq.gz \
  "$SCRATCH"

#######################################
# Trim + assemble per sample
#######################################
for r1 in *_R1.fastq.gz; do
    base=${r1%_R1.fastq.gz}
    r2=${base}_R2.fastq.gz

    echo "Processing ${base}"

    fastqc -o . "$r1" "$r2"

    fastp \
        -i "$r1" -I "$r2" \
        -o "${base}_R1.trimmed.fastq.gz" \
        -O "${base}_R2.trimmed.fastq.gz"

    rm "$r1" "$r2"

    spades.py \
        --isolate \
        -t 32 \
        -1 "${base}_R1.trimmed.fastq.gz" \
        -2 "${base}_R2.trimmed.fastq.gz" \
        -o "${base}.spades"
done

#######################################
# Sync back
#######################################
OUTDIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project/B_alpicola/outputs/spades
mkdir -p "$OUTDIR"

rsync -av *.spades "$OUTDIR"

rm -rf "$SCRATCH"
echo "Done."