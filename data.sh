#!/usr/bin/env bash
set -euo pipefail

# Usage helper
usage() {
  echo "Usage: $0 -d DATA_DIR [-t THREADS]" >&2
  exit 1
}

# Default threads = number of cores or 1
THREADS=$(nproc 2>/dev/null || echo 1)
DBDIR=""

# Parse options
while getopts "d:t:" opt; do
  case $opt in
    d) DBDIR=$OPTARG ;;
    t) THREADS=$OPTARG ;;
    *) usage ;;
  esac
done

# DATA_DIR is mandatory
[[ -n "$DBDIR" ]] || usage

# Create per-db subdirectories
mkdir -p \
  "$DBDIR/Pfam_v32" \
  "$DBDIR/plasx" \
  "$DBDIR/platon" \
  "$DBDIR/hotspot"\
  "$DBDIR/plasclass"

# 1) NCBI COGs via anvio-8
echo "Installing NCBI COGs (COG20) into $DBDIR/COG14"
conda run -n anvio-8 anvi-setup-ncbi-cogs \
  --cog-version COG20 \
  --cog-data-dir "$DBDIR/COG20/" \
  -T "$THREADS" \
  > /dev/null

# 2) Pfams via anvio-8
echo "Installing Pfam (v32.0) into $DBDIR/Pfam_v32"
conda run -n anvio-8 anvi-setup-pfams \
  --pfam-version 32.0 \
  --pfam-data-dir "$DBDIR/Pfam_v32" \
  > /dev/null

# 3) PlasX profiles & coefficients
echo "Downloading PlasX profiles & coefficients into $DBDIR/plasx"
conda run -n plasx plasx setup \
  --de-novo-families 'https://zenodo.org/record/5819401/files/PlasX_mmseqs_profiles.tar.gz' \
  --coefficients    'https://zenodo.org/record/5819401/files/PlasX_coefficients_and_gene_enrichments.txt.gz' \
  -o "$DBDIR/plasx" \
  > /dev/null

# 4) Platon database
echo "Fetching Platon DB into $DBDIR/platon"
wget -qO "$DBDIR/platon/db.tar.gz" \
  https://zenodo.org/record/4066768/files/db.tar.gz
tar -xzf "$DBDIR/platon/db.tar.gz" -C "$DBDIR/platon" > /dev/null
rm "$DBDIR/platon/db.tar.gz"

# 5) HOTSPOT database
echo "Downloading HOTSPOT database and models into $DBDIR/hotspot"
gdown 1ZSTz3kotwF8Zugz_aBGDtmly8BVo9G4T -O "$DBDIR/hotspot/database.tar.gz"
tar -xzf "$DBDIR/hotspot/database.tar.gz" -C "$DBDIR/hotspot/" > /dev/null
rm "$DBDIR/hotspot/database.tar.gz"

gdown 1bnA1osvYDgYBi-DRFkP-HrvcnvBvbipF -O "$DBDIR/hotspot/models.tar.gz"
tar -xzf "$DBDIR/hotspot/models.tar.gz" -C "$DBDIR/hotspot/" > /dev/null
rm "$DBDIR/hotspot/models.tar.gz"

git clone https://github.com/Shamir-Lab/PlasClass.git "$DBDIR/plasclass"

echo "All databases downloaded"
