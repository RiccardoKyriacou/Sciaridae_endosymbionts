#!/bin/bash -l

#SBATCH --job-name=sra-toolkit
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32gb
#SBATCH --export=ALL
#SBATCH --time=3-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --output=sra-toolkit.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -e
hostname

source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/genomics

BASE_DIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project

########################################################
# Species + SRR list
########################################################
# Make bash  array
declare -A SAMPLES=(
    [B_confinis]=SRR29039101 #Bradysia_confinis
    [L_agraria]=SRR29039068 #Lycoriella_agraria
    [B_desolata]=SRR29039102 #Bradysia_desolata
    [B_pectoralis]=SRR29039103 #Bradysia_pectoralis
    [B_odoriphaga]=SRR11366020 #Bradysia_odoriphaga
    [P_flavipes]=SRR5217995 #Phytosciara_flavipes
    [T_splendens]=SRR5218407 #Trichosia_splendensls 
)

########################################################
# Loop over species
########################################################
for SPECIES in "${!SAMPLES[@]}"; do
    SRR=${SAMPLES[$SPECIES]}

    echo "Processing $SPECIES ($SRR)"
    
    # make appropriate dir
    WORKDIR=${BASE_DIR}/${SPECIES}/outputs/fastq
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"

    export TMPDIR=$WORKDIR/tmp
    mkdir -p "$TMPDIR"

    fasterq-dump "$SRR" \
        --split-files \
        --threads 32 \
        --outdir "$WORKDIR" \
        --temp "$TMPDIR"

    pigz -p 32 ${SRR}*.fastq
done