#!/bin/bash -l

#SBATCH --job-name=Hifiasm
#SBATCH --nodes=1
#SBATCH --ntasks=32
#SBATCH --export=ALL
#SBATCH --time=0-90:00:00
#SBATCH --partition ac3-compute
#SBATCH --mem=128gb
#SBATCH --output=Hifiasm.%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=s2673271@ed.ac.uk

set -e

SCRATCH=/scratch/${USER}/hifiasm.${SLURM_JOB_ID}
mkdir -p $SCRATCH
cd $SCRATCH
OUTDIR="/mnt/loki/ross/flies/sciaridae/endosymbiont_project/B_ocellaris/outputs"

source /home/s2673271/miniforge3/etc/profile.d/conda.sh     
conda activate /home/s2673271/miniforge3/envs/genomics

echo "Syncing files..."
# B Osc reads
rsync -av /mnt/loki/ross/sequencing/raw/202507_Bradysia_ocellaris_WGS_HiFi/B.ocellaris_M_2/hifi_reads/m84140_250716_161940_s1.hifi_reads.16_UDI_1_A01_F--16_UDI_1_A01_R.hifi_reads.fastq.gz $SCRATCH

READS="m84140_250716_161940_s1.hifi_reads.16_UDI_1_A01_F--16_UDI_1_A01_R.hifi_reads.fastq.gz"

echo "Assembling for m testes..."
hifiasm -o B_ocellaris.asm -t 32 $READS

# Generate fasta files
awk '$1 == "S" {print ">"$2"\n"$3}'  B_ocellaris.asm.bp.p_ctg.gfa > B_ocellaris_p_ctg.fa

#Summary stats 
quast.py B_ocellaris_p_ctg.fa -o quast_B_ocellaris

rsync -av \
    $SCRATCH/B_ocellaris* \
    $SCRATCH/quast_B_ocellaris \
    $OUTDIR

echo "Cleaning up..."
rm -rf ${SCRATCH}

