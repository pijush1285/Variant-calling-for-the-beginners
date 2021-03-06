#!/bin/bash

echo -e "-----------------------------------------------------------------------------"
echo -e "                                                                             "
echo -e "This script will perform the variant calling operation step by step !"
echo -e "This program is developed for the analysis of the lab made dataset....       "
echo -e "For this analysis I have used BWA, samtools and bcftools."
echo -e "                                                                             "
echo -e "-----------------------------------------------------------------------------"



#The code given below will ask the names of the reference file, read 1 and read 2 files.
read -p " enter your Reference:" refFasta
read -p " enter the Read 1:" Read1
read -p " enter the Read 2:" Read2

#Or the user can directly assigne the files names into the variables
refFasta=finalRefGen.fa
Read1=NRead3.fq
Read2=NRead4.fq

echo "-------------------------------------------"
echo "All the sample files are taken as an Input"
echo "-------------------------------------------"


#Location of the tools.
#If you are using conda and installing all of the packages inside, 
#you may not need to provide the location of those packages.
bwa=~/bwa
samtools=~/samtools
bcftools=~/bcftools


#Creating index for the reference file.
$bwa index $refFasta

echo "-------------------------------------------"
echo "Index completed"
echo "-------------------------------------------"


#Now mapping all those files
$bwa mem -t 20 $refFasta $Read1 $Read2 > mappedR1R2.sam

echo "-------------------------------------------"
echo "Mapping completed"
echo "-------------------------------------------"


#Convert SAM to BAM
$samtools view -S -b $pl/mappedR1R2.sam > mappedR1R2a.bam -@ 20

echo "-------------------------------------------"
echo "Sam to Bam compleated"
echo "-------------------------------------------"


#Sort BAM files
$samtools sort $pl/mappedR1R2a.bam > mappedR1R2_sorted.bam

echo "-------------------------------------------"
echo "Sort compleated"
echo "-------------------------------------------"



#Now gather all the BAM files.
$samtools merge finalBamFile.bam mappedR*R*_sorted.bam
#This marged command marged the file but producing such a file which is not producing .bcf file

#You can use picard for merging the bam files. Doing analysis in some simulated data I have face 
#some problem in merging the bam files using samtools code and picard code. Thus I have merged 
#the vcf file at the end. To get the code please see the code BWA_Gatk_v2.sh.
java -jar $picard MergeSamFiles \
      I=input_1.bam \
      I=input_2.bam \
      O=output_merged_files.bam


#Samtools indexing is there.
$samtools faidx $refFasta

echo "-------------------------------------------"
echo "Samtool index is completed"
echo "-------------------------------------------"


#Use this one insted of using upper two line.
$bcftools mpileup -f $refFasta mappedR1R2_sorted.bam | $bcftools call -mv -Ob -o mappedR1R2_sorted_var.bcf 

echo "-------------------------------------------"
echo "Mpileup is compleated"
echo "-------------------------------------------"


#Finally the vcf are called. Remember to put the address of the vcfutils.pl program, the example is given below.
varFilter=/data/sata_data/workshop/wsu28/packages/samtools1/bcftools/misc
$bcftools view mappedR1R2_sorted_var.bcf | $varFilter/vcfutils.pl varFilter -Q > MappedR1R2.var-final.vcf

echo "-------------------------------------------"
echo "Final vcf calling is compleated"
echo "-------------------------------------------"


#Filtering Variants
#Researchers use external ground truth data in most applications to calibrate a pipeline of calling variants.
#We don't know the ground truth in our case so we'll explain some filtering choices based on quantitative 
#statistics like the transition / transversion ratio. Transitions are much more common in most species than 
#transversions, so we would expect a transition / transversion ratio of around 2 for humans.
bcftools stats MappedR1R2.var-final.vcf.gz | grep "TSTV"
bcftools filter -i '%QUAL>20' MappedR1R2.var-final.vcf.gz  | bcftools stats | grep "TSTV"
bcftools filter -e '%QUAL<=20 || %QUAL/INFO/AO<=2 || SAF<=2 || SAR<=2' MappedR1R2.var-final.vcf.gz  | bcftools stats | grep "TSTV"


#In this section we can compaire the vcf files. 
#Total no of SNP
$bcftools view -v snps MappedR1R2.var-final.vcf | grep -v "^#" | wc -l
$bcftools view -v snps MappedR3R4.var-final.vcf | grep -v "^#" | wc -l


#For copmaring more than one file first we need to convert .vcf file into .vcf.gz file.
$bcftools view output_1000000snps.vcf -Oz -o fileOriginal.vcf.gz


#This code is used for some kind of arranging the snps. 
$bcftools view -v snps fileR1R2.vcf.gz | perl -lane 'if (/^#/) { print } elsif (length($F[3]) == 1) { print }' | bgzip > snp12.vcf.gz
$bcftools view -v snps fileR3R4.vcf.gz | perl -lane 'if (/^#/) { print } elsif (length($F[3]) == 1) { print }' | bgzip > snp34.vcf.gz


#bgzip and tabix
#We can speed up random access to VCF files by compressing them with bgzip, in the htslib package. bgzip is a "block-based GZIP", 
#which compresses files in chunks of lines. This chunking let's us quickly seek to a particular part of the file, 
#and support indexes to do so.
bgzip snp12.vcf # makes snp12.vcf.gz
tabix -p vcf snp12.vcf.gz
tabix -p vcf snp34.vcf.gz


#If your package is install in conda you can use the code given below. 
#Now to know how many SNPs is there in the file.
bcftools view -v snps snp12.vcf | grep -v "^#" | wc -l


#Intersect between processed one and the origianl
bedtools intersect -u -a snp12.vcf.gz -b snp34.vcf.gz | wc -l


#Calculate Jaccard index. This code is used for calculating the intersection between two files.
bedtools jaccard -a snp12.vcf.gz -b snp34.vcf.gz


