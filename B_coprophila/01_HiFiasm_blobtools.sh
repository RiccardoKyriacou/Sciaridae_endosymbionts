#!/bin/bash -l

#SBATCH --job-name=hifiasm_blobtools2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64gb
#SBATCH --export=ALL
#SBATCH --time=3-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --output=hifiasm_blobtools2.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -e

# Don't change these
BLASTDB="/mnt/loki/db/core_nt/core_nt"
# Get NCBI TAXDUMP - Unc
# mkdir -p ./taxdump
# curl https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz | tar xzf - -C ./taxdump
TAXDUMP="/mnt/loki/ross/flies/chironomidae/Belgica_antarctica/soma_v_germline/05_assemble_pulled_reads/outputs/taxdump"

# change these 
BLOBDIR="Bcop_blobdir"
BLAST_OUT="Bcop_vs_nt.blastn"
BLOBNAME="B_coprophila" 

# change these 
READS="/mnt/loki/ross/flies/sciaridae/GRCs/pacbio_long_reads/outputs/ERR12736861.fastq.gz"

# Make working dir
WORKDIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project/"${BLOBNAME}"/outputs/blobtools
mkdir -p $WORKDIR
cd $WORKDIR

###############################################################
# Run HiFiasm 
###############################################################
# SCRATCH=/scratch/${USER}/hifiasm.${SLURM_JOB_ID}
# mkdir -p $SCRATCH
# cd $SCRATCH

# # Conda for hifiasm
# source /home/s2673271/miniforge3/etc/profile.d/conda.sh     
# conda activate /home/s2673271/miniforge3/envs/genomics

# echo "Syncing files..."
# rsync -av "$READS" "$SCRATCH"
# # Get basename
# READS_BASENAME=$(basename "$READS")

# echo "Running hifiasm"
# hifiasm --primary -o ${BLOBNAME}.asm -t 32 $READS_BASENAME

# awk '$1 == "S" {print ">"$2"\n"$3}' \
#   ${BLOBNAME}.asm.p_ctg.gfa > ${BLOBNAME}_p_ctg.fa

# rsync -av ${BLOBNAME}_p_ctg.fa $WORKDIR

# echo "Cleaning up..."
# rm -rf "${SCRATCH}"

###############################################################
# Create Blobtools db
###############################################################
# Conda for blobtools
source /home/s2673271/miniforge3/etc/profile.d/conda.sh     
conda activate /home/s2673271/miniforge3/envs/blobtools2
cd $WORKDIR

ASM=/mnt/loki/ross/flies/sciaridae/endosymbiont_project/B_coprophila/outputs/blobtools/${BLOBNAME}_p_ctg.fa

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

# ###############################################################
# # Add Mapping to blobtools
# ###############################################################
# # Run minimap2
echo "Running minimap2"
minimap2 -ax map-hifi \
         -t 32 ${ASM} \
         ${READS} \
| samtools sort -@32 -O BAM -o ${ASM}.bam -
samtools index -c ${ASM}.bam 

#add to dir 
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
    -o ${BLOBNAME} # change this

~/programmes/blobtools/blobtools view -i ${BLOBNAME}.blobDB.json
~/programmes/blobtools/blobtools plot -i ${BLOBNAME}.blobDB.json 


###############################################################
# Filter using blobtools2
###############################################################
# conda deactivate
# source /home/s2673271/miniforge3/etc/profile.d/conda.sh     
# conda activate /home/s2673271/miniforge3/envs/blobtoolkit

# blobtools filter \
#   --param bestsumorder_phylum--Keys=Bacteria \
#   --fasta ${ASM} \
#   --output male_GRC_clean \
#   --suffix cleaned \
#   male_GRC_blobdir
