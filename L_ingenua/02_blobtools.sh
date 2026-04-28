#!/bin/bash -l

#SBATCH --job-name=blobtools2
#SBATCH --nodes=1
#SBATCH --ntasks=32
#SBATCH --export=ALL
#SBATCH --time=3-00:00:00
#SBATCH --partition=ac3-compute
#SBATCH --mem=32gb
#SBATCH --output=blobtools2.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -e
source /home/s2673271/miniforge3/etc/profile.d/conda.sh     
conda activate /home/s2673271/miniforge3/envs/blobtools2

# Don't change these
BLASTDB="/mnt/loki/db/core_nt/core_nt"
# Get NCBI TAXDUMP - Unc
# mkdir -p ./taxdump
# curl https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz | tar xzf - -C ./taxdump
TAXDUMP="/mnt/loki/ross/flies/chironomidae/Belgica_antarctica/soma_v_germline/05_assemble_pulled_reads/outputs/taxdump"

# change these 
BLOBDIR="Ling_blbodir"
BLAST_OUT="Ling_vs_nt.blastn"
BLOBNAME="L_ingenua" 

# change these 
ASM="/mnt/loki/ross/flies/sciaridae/endosymbiont_project/L_ingenua/outputs/Hifiasm/L_ingenua_p_ctg.fa"
READS="/mnt/loki/ross/flies/sciaridae/endosymbiont_project/${BLOBNAME}/outputs/fastq/*.fastq.gz"

# change these 
WORKDIR=/mnt/loki/ross/flies/sciaridae/endosymbiont_project/"${BLOBNAME}"/outputs/blobtools
mkdir -p $WORKDIR
cd $WORKDIR

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

# ###############################################################
# # Add Mapping to blobtools
# ###############################################################
# # Run minimap2
echo "Running minimap2"
echo "For males"
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

