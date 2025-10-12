#!/usr/bin/env bash
set -Euo pipefail

STEP="init"
# DEBUG 
trap 'rc=$?; echo "❌ Failed at step: ${STEP}" >&2; echo "   Command: $BASH_COMMAND" >&2; echo "   Location: ${BASH_SOURCE[0]}:${LINENO} (exit $rc)" >&2' ERR

log() { printf '[%s] %s\n' "$(date +'%F %T')" "$*" >&2; }
has_content() { find "$1" -mindepth 1 -print -quit 2>/dev/null | grep -q .; }

FORCE=0
if [[ "${1:-}" == "--force" || "${1:-}" == "--forece" ]]; then
  FORCE=1
fi

STEP="create tmp workspace"
tmp="$(mktemp -d)"
cd "$tmp"

STEP="detect package manager"
if command -v mamba >/dev/null 2>&1; then
  PM="mamba"
elif command -v conda >/dev/null 2>&1; then
  PM="conda"
else
  echo "conda/mamba not found in PATH" >&2
  exit 1
fi

# Get the conda/mamba base 
BASE="$($PM info --base)"
BASE="${BASE##*: }"

env_path() { echo "$BASE/envs/$1"; }
env_exists() { [[ -d "$(env_path "$1")/conda-meta" ]]; }

# >>> Miniforge support <<<
export -f log
if [[ "$PM" == "conda" ]]; then
  CONDA_INIT="source \"$BASE/etc/profile.d/conda.sh\"; "
else
  CONDA_INIT=""
fi
# >>> End addition <<<

add_headless_hooks() {
  local tgt="$1"
  mkdir -p "$tgt/etc/conda/activate.d" "$tgt/etc/conda/deactivate.d" "$HOME/.config/matplotlib"

  cat > "$tgt/etc/conda/activate.d/zz-plaswrap-headless.sh" <<'EOF'
export QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen}
export MPLBACKEND=${MPLBACKEND:-Agg}
EOF

  cat > "$tgt/etc/conda/deactivate.d/zz-plaswrap-headless.sh" <<'EOF'
unset QT_QPA_PLATFORM
unset MPLBACKEND
EOF

  echo "backend: Agg" > "$HOME/.config/matplotlib/matplotlibrc"
}
if (( FORCE == 1 )); then
  STEP="force cleanup of old env folders"
  log "Removing existing env folders (force)"
  for n in plaswrap anvio-8 plasx hotspot plasclass platon; do
    d="$(env_path "$n")"
    [[ -d "$d" ]] && rm -rf "$d"
  done
fi

# 1) PLASWRAP (prebuilt env tarball) — quiet
STEP="install plaswrap"
ENV_NAME="plaswrap"
TARGET="$(env_path "$ENV_NAME")"

if env_exists "$ENV_NAME" && (( FORCE == 0 )); then
  log "plaswrap: exists → skip"
else
  [[ -d "$TARGET" ]] && rm -rf "$TARGET"
  log "plaswrap: downloading release 0.1.3"
  if command -v wget >/dev/null 2>&1; then
    wget -q --no-check-certificate -O plaswrap.tar.gz https://github.com/braddmg/PLASWRAP/releases/download/v0.1.4/plaswrap-0.1.4-linux-x86_64.tar.gz
  else
    curl -sL -o plaswrap.tar.gz https://github.com/braddmg/PLASWRAP/releases/download/v0.1.4/plaswrap-0.1.4-linux-x86_64.tar.gz
  fi
  [[ -s plaswrap.tar.gz ]] || { echo "failed to download PLASWRAP, please contact: bradd.mendoza@ucr.ac.cr" >&2; exit 2; }
  log "plaswrap: extracting files"
  mkdir -p "$TARGET"

  # Handle top-level dir in tarball and run conda-unpack if present
  first_entry="$(tar -tzf plaswrap.tar.gz | head -1 || true)"
  if [[ "$first_entry" == */ ]]; then
    tar -xzf plaswrap.tar.gz -C "$TARGET" --strip-components=1
  else
    tar -xzf plaswrap.tar.gz -C "$TARGET"
  fi
  if [[ -x "$TARGET/bin/conda-unpack" ]]; then
    "$TARGET/bin/conda-unpack" >/dev/null 2>&1 || true
  fi

  add_headless_hooks "$TARGET"
  log "plaswrap: installed → $TARGET"
fi

echo "Activate: conda activate plaswrap"
echo "Test: plaswrap classify -h"

mkenv() {
  local name="$1"; shift
  STEP="check env $name"
  if env_exists "$name" && (( FORCE == 0 )); then
    log "$name: exists → skip"; return 0
  fi
  local p; p="$(env_path "$name")"
  [[ -d "$p" ]] && rm -rf "$p"
  STEP="create env $name"
  log "$name: creating..."
  bash -lc "${CONDA_INIT}set -Eeuo pipefail; trap 'rc=\$?; echo \"❌ [$name] command failed: \$BASH_COMMAND (exit \$rc)\" >&2' ERR; $*"
  log "$name: ready"
}

# 2) anvio-8
STEP="prepare anvio-8"
mkenv anvio-8 "
  $PM create -y --name anvio-8 python=3.10 >/dev/null &&
  $PM install -y -n anvio-8 -c conda-forge -c bioconda \
    python=3.10 sqlite=3.46 prodigal idba mcl \
    muscle=3.8.1551 famsa hmmer diamond blast \
    megahit spades bowtie2 bwa graphviz \
    'samtools>=1.9' trimal iqtree trnascan-se \
    fasttree vmatch r-base r-tidyverse \
    r-optparse r-stringi r-magrittr \
    bioconductor-qvalue meme ghostscript \
    nodejs=20.12.2 datrie >/dev/null &&
  log \"anvio-8: downloading sources, see: https://anvio.org/install/linux/stable\" &&
  curl -sL \
    https://github.com/merenlab/anvio/releases/download/v8/anvio-8.tar.gz \
    -o anvio-8.tar.gz &&
  [[ -s anvio-8.tar.gz ]] &&
  conda run -n anvio-8 pip install anvio-8.tar.gz >/dev/null
"

# 3) plasx
STEP="prepare plasx"
mkenv plasx "
  $PM create -y --name plasx \
    -c anaconda -c conda-forge -c bioconda \
    --override-channels --strict-channel-priority \
    numpy pandas scipy scikit-learn numba python-blosc mmseqs2=10.6d92c git >/dev/null &&
  log \"plasx: downloading, see: https://github.com/michaelkyu/PlasX\" &&
  rm -rf PlasX &&
  git clone https://github.com/michaelkyu/PlasX PlasX >/dev/null &&
  cd PlasX
  conda run -n plasx pip install . >/dev/null
"

# 4) hotspot
STEP="prepare hotspot"
mkenv hotspot "
  echo '==> hotspot: downloading' &&
  rm -rf HOTSPOT &&
  git clone https://github.com/Orin-beep/HOTSPOT HOTSPOT >/dev/null &&
  log \"hotspot: installing, see: https://github.com/Orin-beep/HOTSPOT\" &&
  log \"hotspot: additionally adding krona: https://github.com/marbl/Krona/wiki\" &&
  $PM env create -y -f HOTSPOT/environment.yaml -n hotspot >/dev/null &&
  $PM install -y -n hotspot -c bioconda krona >/dev/null
"

# 5) plasclass
STEP="prepare plasclass"
mkenv plasclass "$PM create -y -n plasclass -c conda-forge -c bioconda plasclass >/dev/null"

# 6) platon
STEP="prepare platon"
mkenv platon "$PM create -y -n platon -c conda-forge -c bioconda -c defaults platon >/dev/null"

STEP="cleanup tmp"
cd /
rm -rf "$tmp"

STEP="done"
log "All done."
