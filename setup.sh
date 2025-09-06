#!/usr/bin/env bash
set -euo pipefail

# 0) Ensure mamba is available in base
if ! command -v mamba &>/dev/null; then
  echo "Installing mamba in base"
  conda install -n base -y -c conda-forge mamba > /dev/null
fi

# 1) Prepare temp workspace
tmp=$(mktemp -d)
cd "$tmp"

# 2) Install Anvio-8
echo "Installing anvio-8"
mamba create -y --name anvio-8 python=3.10 > /dev/null
mamba install -y -n anvio-8 \
  -c conda-forge -c bioconda \
  python=3.10 sqlite=3.46 prodigal idba mcl \
  muscle=3.8.1551 famsa hmmer diamond blast \
  megahit spades bowtie2 bwa graphviz \
  "samtools>=1.9" trimal iqtree trnascan-se \
  fasttree vmatch r-base r-tidyverse \
  r-optparse r-stringi r-magrittr \
  bioconductor-qvalue meme ghostscript \
  nodejs=20.12.2 > /dev/null

echo "Downloading Anvio-8 sources"
curl -sL \
  https://github.com/merenlab/anvio/releases/download/v8/anvio-8.tar.gz \
  -o anvio-8.tar.gz

echo "Installing anvio-8 via pip"
conda run -n anvio-8 pip install anvio-8.tar.gz > /dev/null

# 3) Install PlasX
echo "Installing plasx"
mamba create -y --name plasx \
  -c anaconda -c conda-forge -c bioconda \
  --override-channels --strict-channel-priority \
  numpy pandas scipy scikit-learn numba \
  python-blosc mmseqs2=10.6d92c git > /dev/null

git clone https://github.com/michaelkyu/PlasX > /dev/null
cd PlasX
echo "Installing plasx via pip"
conda run -n plasx pip install . > /dev/null
cd ..

# 4) install HOTSPOT
echo "Installing hotspot" 
git clone https://github.com/Orin-beep/HOTSPOT > /dev/null
mamba env create -y -f HOTSPOT/environment.yaml -n hotspot > /dev/null

#5) install plasclass
git clone https://github.com/Shamir-Lab/PlasClass.git > /dev/null
conda create -n plasclass python=3.7.12 
conda run -n plasclass python PlasClass/setup.py install

#6) install coveragem


# 5) Cleanup & finish
cd /
rm -rf "$tmp"
echo "All environments have been created successfully"


