#!/usr/bin/env bash
set -euo pipefail

# --- Usage ---
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 2 ]]; then
  echo "Usage: $0 -d DB_DIR [-t THREADS] [--force]"
  exit 1
fi

DBDIR=""
THREADS="$(command -v nproc >/dev/null 2>&1 && nproc || echo 1)"
FORCE=0

while (( "$#" )); do
  case "$1" in
    -d) DBDIR="$2"; shift 2 ;;
    -t) THREADS="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    *) shift ;;
  esac
done

mkdir -p "$DBDIR"

log() { printf '[%s] %s\n' "$(date +'%F %T')" "$*" >&2; }
has_content() { find "$1" -mindepth 1 -print -quit 2>/dev/null | grep -q .; }

# Check a single matching folder.
resolve_one() {
  local root="$1" pat="$2"
  local dirs=()
  shopt -s nullglob
  for d in "$root"/$pat; do [[ -d "$d" ]] && dirs+=("$d"); done
  shopt -u nullglob
  if (( ${#dirs[@]} > 1 )); then
    echo "ERROR: Multiple directories match '$root/$pat':" >&2
    printf ' - %s\n' "${dirs[@]}" >&2
    exit 2
  fi
  [[ ${#dirs[@]} -eq 1 ]] && echo "${dirs[0]}" || echo ""
}

# --- 1) COGs (anvio-8) ---
COG_FOUND="$(resolve_one "$DBDIR" 'COG*')"
if [[ -n "$COG_FOUND" && $FORCE -eq 0 && $(has_content "$COG_FOUND" && echo 1 || echo 0) -eq 1 ]]; then
  log "Skipping COG (found: $COG_FOUND)"
else
  COG_DIR="${COG_FOUND:-"$DBDIR/COG20"}"
  mkdir -p "$COG_DIR"
  log "Installing COG20 → $COG_DIR"
  conda run -n anvio-8 anvi-setup-ncbi-cogs \
    --cog-version COG20 --cog-data-dir "$COG_DIR" -T "$THREADS"
fi

# --- 2) Pfam (anvio-8) ---
PFAM_FOUND="$(resolve_one "$DBDIR" 'Pfam*')"
if [[ -n "$PFAM_FOUND" && $FORCE -eq 0 && $(has_content "$PFAM_FOUND" && echo 1 || echo 0) -eq 1 ]]; then
  log "Skipping Pfam (found: $PFAM_FOUND)"
else
  PFAM_DIR="${PFAM_FOUND:-"$DBDIR/Pfam_v32"}"
  mkdir -p "$PFAM_DIR"
  log "Installing Pfam v32 → $PFAM_DIR"
  conda run -n anvio-8 anvi-setup-pfams --pfam-version 32.0 --pfam-data-dir "$PFAM_DIR"
fi

# --- 3) PlasX ---
PLASX_DIR="$DBDIR/plasx"
if [[ $FORCE -eq 0 && -d "$PLASX_DIR" && $(has_content "$PLASX_DIR" && echo 1 || echo 0) -eq 1 ]]; then
  log "Skipping PlasX (found: $PLASX_DIR)"
else
  mkdir -p "$PLASX_DIR"
  log "Installing PlasX assets → $PLASX_DIR"
  conda run -n plasx plasx setup \
    --de-novo-families 'https://zenodo.org/record/5819401/files/PlasX_mmseqs_profiles.tar.gz?download=1' \
    --coefficients    'https://zenodo.org/record/5819401/files/PlasX_coefficients_and_gene_enrichments.txt.gz?download=1' \
    -o "$PLASX_DIR"
fi

# --- 4) Platon DB ---
PLATON_DIR="$DBDIR/platon"
if [[ $FORCE -eq 0 && -d "$PLATON_DIR" && $(has_content "$PLATON_DIR" && echo 1 || echo 0) -eq 1 ]]; then
  log "Skipping Platon (found: $PLATON_DIR)"
else
  mkdir -p "$PLATON_DIR"
  TARGZ="$PLATON_DIR/db.tar.gz"
  log "Downloading Platon DB tar → $TARGZ"
  wget https://zenodo.org/record/4066768/files/db.tar.gz --no-check-certificate -O "$TARGZ"
  log "Extracting Platon DB → $PLATON_DIR"
  tar -xzf "$TARGZ" -C "$PLATON_DIR"
  rm -f "$TARGZ"
fi

# --- 5) HOTSPOT ---
HOTSPOT_DIR="$DBDIR/hotspot"
mkdir -p "$HOTSPOT_DIR"

if [[ -d "$HOTSPOT_DIR/HOTSPOT/.git" && $FORCE -eq 0 ]]; then
  log "Skipping HOTSPOT repo (found)"
else
  log "Cloning HOTSPOT repo → $HOTSPOT_DIR/HOTSPOT"
  rm -rf "$HOTSPOT_DIR/HOTSPOT"
  git clone https://github.com/Orin-beep/HOTSPOT "$HOTSPOT_DIR/HOTSPOT"
fi
# --- 5.1) models and database ---
if command -v gdown >/dev/null 2>&1; then
  if [[ $FORCE -ne 0 || ! -d "$HOTSPOT_DIR/database" || ! $(has_content "$HOTSPOT_DIR/database" && echo 1 || echo 0) -eq 1 ]]; then
    mkdir -p "$HOTSPOT_DIR/database"
    log "Downloading HOTSPOT database (gdown) → $HOTSPOT_DIR"
    gdown "https://drive.google.com/uc?id=1ZSTz3kotwF8Zugz_aBGDtmly8BVo9G4T" -O "$HOTSPOT_DIR/database.tar.gz"
    tar -xzf "$HOTSPOT_DIR/database.tar.gz" -C "$HOTSPOT_DIR"
    rm -f "$HOTSPOT_DIR/database.tar.gz"
  else
    log "Skipping HOTSPOT database (found)"
  fi

  if [[ $FORCE -ne 0 || ! -d "$HOTSPOT_DIR/models" || ! $(has_content "$HOTSPOT_DIR/models" && echo 1 || echo 0) -eq 1 ]]; then
    mkdir -p "$HOTSPOT_DIR/models"
    log "Downloading HOTSPOT models (gdown) → $HOTSPOT_DIR"
    gdown "https://drive.google.com/uc?id=1bnA1osvYDgYBi-DRFkP-HrvcnvBvbipF" -O "$HOTSPOT_DIR/models.tar.gz"
    tar -xzf "$HOTSPOT_DIR/models.tar.gz" -C "$HOTSPOT_DIR"
    rm -f "$HOTSPOT_DIR/models.tar.gz"
  else
    log "Skipping HOTSPOT models (found)"
  fi
else
  log "gdown not found; skipping HOTSPOT database/models (repo cloned)."
fi

# --- 6) PlasClass ---
PLASCLASS_DIR="$DBDIR/plasclass"
if [[ -d "$PLASCLASS_DIR/.git" && $FORCE -eq 0 ]]; then
  log "Skipping PlasClass (found)"
else
  log "Cloning PlasClass → $PLASCLASS_DIR"
  rm -rf "$PLASCLASS_DIR"
  git clone https://github.com/Shamir-Lab/PlasClass.git "$PLASCLASS_DIR"
fi

log "All databases ready."

