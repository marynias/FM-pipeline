#!/bin/bash
# 16-1-2018 MRC-Epid JHZ

export rt=/gen_omics/data/EPIC-Norfolk/HRC/binary_ped
export BINARY_PED=$rt/HRC
export exclude_sample=$rt/exclude.id
export exclude_snp=$rt/exclude.snps
export ID3=$rt/id3.txt
export threads=10

echo "SNP A1 A2 freq b se p N" > gcta.dat
sort -k9,9n -k10,10n $1 | awk '
{
  a1=toupper($2)
  a2=toupper($3)
  chr=$9
  pos=$10
  if (a1<a2) snpid=chr ":" pos "_" a1 "_" a2
  else snpid=chr ":" pos "_" a2 "_" a1
  $1=snpid
  $2=a1
  $3=a2
  print $1,$2,$3,$4,$5,$6,$7,$8
}' | sort -k1,1 | join -13 -21 $ID3/id3.txt - | \
awk '{$1=$2="";print}' | \
awk '{$1=$1};1' >> $1.dat

export OPT1=""
if [ -f $exclude_sample ] && [ ! -z "$exclude_sample" ]; then export OPT1="--remove $exclude_smaple"; fi
export OPT2=""
if [ -f $exclude_snp ] && [ ! -z "$exclude_snp" ]; then export OPT2="--exclude $exclude_snp"; fi

gcta64 --bfile $BINARY_PED $OPT1 $OPT2 --cojo-file $1.dat --cojo-slct --thread-num $threads --out $1

setup() {
stata <<END
gzuse /gen_omics/data/EPIC-Norfolk/HRC/SNPinfo
gen A1A2=cond(A1<A2,"_"+A1+"_"+A2,"_"+A2+"_"+A1)
gen snpid=string(chr)+":"+string(pos,"%12.0f")+A1A2
sort snpid
gen maf=cond(FreqA2<=0.5, FreqA2, 1-FreqA2)
gen MAC=2*21044*maf
outsheet snpid if (MAC<3 | info<0.4) using exclude.snps, noname noquote replace
keep rsid RSnum snpid
outsheet using id3.txt, delim(" ") noname noquote replace
END
export GEN=/gen_omics/data/EPIC-Norfolk/HRC
export sample=/gen_omics/data/EPIC-Norfolk/HRC/EPIC-Norfolk.sample
cd /gen_omics/data/EPIC-Norfolk/HRC/binary_ped
seq 22 | parallel --env GEN --env sample -C' ' 'sge "/genetics/bin/plink2 --bgen $GEN/chr{}.bgen --sample $sample --chr {} --make-bed --out chr{}"'
rm merge-list
touch merge-list
for i in $(seq 22); do echo chr${i} >> merge-list; done
/genetics/bin/plink-1.9 --merge-list merge-list --make-bed --out HRC
}

