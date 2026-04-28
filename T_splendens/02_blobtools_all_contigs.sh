#!/bin/bash -l

#SBATCH --job-name=blobtools2_all_contigs
#SBATCH --nodes=1
#SBATCH --ntasks=32
#SBATCH --export=ALL
#SBATCH --time=3-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --mem=32gb
#SBATCH --output=blobtools2_all_contigs.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

hostname
set -e
source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/blobtools2

###############################################################
# Change these variables
###############################################################
BLOBNAME="T_splendens"
SP_NAME="Tspl"
################################################################

ASM="/mnt/loki/ross/flies/sciaridae/endosymbiont_project/${BLOBNAME}/outputs/spades_meta/contigs.fasta"
READS_1=(/mnt/loki/ross/flies/sciaridae/endosymbiont_project/${BLOBNAME}/outputs/fastq/*_1.fastq.gz)
READS_2=(/mnt/loki/ross/flies/sciaridae/endosymbiont_project/${BLOBNAME}/outputs/fastq/*_2.fastq.gz)

###############################################################
# Set up scratcg and stage files
###############################################################
# Don't change these
BLOBDIR="${SP_NAME}_blobdir"
BLAST_OUT="${SP_NAME}_vs_nt.blastn"

# path to db and taxdump
BLASTDB="/mnt/loki/db/core_nt/core_nt"
TAXDUMP="/mnt/loki/ross/flies/chironomidae/Belgica_antarctica/soma_v_germline/05_assemble_pulled_reads/outputs/taxdump"

SCRATCH=/scratch/${USER}/blobtools2.${SLURM_JOB_ID}
OUTDIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project/${BLOBNAME}/outputs/blobtools_all_contigs
mkdir -p $OUTDIR
mkdir -p "$SCRATCH"
cd "$SCRATCH"

# Stage to scratch
rsync -av $ASM "$SCRATCH"
rsync -av $READS_1 "$SCRATCH"
rsync -av $READS_2 "$SCRATCH"

# get scratch name
ASM=$(basename "$ASM")
READS_1=$(basename "$READS_1")
READS_2=$(basename "$READS_2")

###############################################################
# Create Blobtools db
###############################################################
blobtools create \
  --fasta ${ASM} \
  ${BLOBDIR}

##############################################################
# BLAST
##############################################################
echo "running BLASTn"
blastn -db ${BLASTDB} \
       -query ${ASM} \
       -outfmt "6 qseqid staxids bitscore std" \
       -max_target_seqs 10 \
       -max_hsps 1 \
       -evalue 1e-25 \
       -num_threads 32 \
       -out ${BLAST_OUT}

echo "adding BLAST to blobdir"
blobtools add \
  --hits ${BLAST_OUT} \
  --taxrule bestsumorder \
  --taxdump ${TAXDUMP} \
  ${BLOBDIR}

###############################################################
# Add mapping (paired-end Illumina)
###############################################################
echo "Running minimap2 (Illumina PE)"
minimap2 -ax sr --secondary=no \
    -t 32 \
    ${ASM} \
    ${READS_1} ${READS_2} \
| samtools sort -@32 -O BAM -o ${ASM}.bam -

# Index with .csi
samtools index -c ${ASM}.bam

blobtools add \
    --cov ${ASM}.bam \
    ${BLOBDIR}

###############################################################
# View (using blobtools1) - we will then filter using blobtools2 ls
###############################################################
conda deactivate
source /home/s2673271/miniforge3/etc/profile.d/conda.sh
conda activate /home/s2673271/miniforge3/envs/blobtools

~/programmes/blobtools/blobtools create \
    -i ${ASM} \
    -t ${BLAST_OUT} \
    -b ${ASM}.bam \
    -o ${BLOBNAME}

~/programmes/blobtools/blobtools view -i ${BLOBNAME}.blobDB.json
~/programmes/blobtools/blobtools plot -i ${BLOBNAME}.blobDB.json

# ###############################################################
# Sync back
# ###############################################################
rsync -av *.blobDB.* \
  $BLAST_OUT \
  $BLOBDIR \
  $OUTDIR

echo "Cleaning up scratch."
rm -rf "$SCRATCH"

echo "Done."