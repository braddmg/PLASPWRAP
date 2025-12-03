# PLASWRAP
A pipeline for plasmidomic analysis that detects high‑confidence plasmid contigs from metagenomic assemblies and assigns taxonomy using multiple tools.

![PLASWRAP flow](https://raw.githubusercontent.com/braddmg/images/main/plaswrap_flow.png)

## Download
```bash
git clone https://github.com/braddmg/PLASWRAP
cd PLASWRAP
```

# Installation
PLASWRAP is easiest to use through Singularity or Docker because it relies on multiple conda environments.

## Singularity
Download the `.sif` image and run:
```bash
singularity exec plaswrap-0.1.4.sif plaswrap --help
```
Example help output:
```
usage: plaswrap [-h] {classify,refine,GetTaxa} ...
```

## Databases
Download required databases (choose download folder with `-d` and threads with `-t`):
```bash
singularity exec plaswrap-0.1.4.sif download_data.sh -d databases -t 64
```

## Manual installation (conda)
If not using Singularity, run the installer to create all required environments: plaswrap, anvio‑8, plasx, platon, plasclass, and hotspot.
```bash
bash install_plaswrap.sh --force #force will remove environments with the same names and reinstalle them.
```
Then activate and download databases:
```bash
conda activate plaswrap
bash download_data.sh -d ~/databases/plaswrap -t 16
```

# Usage

## 1. Classification
Runs a Snakemake workflow using four tools: PlasX, PlasClass, Platon, and PlasmidHunter. You may choose a subset of tools.

Each FASTA file in the input directory is treated as one sample. Snakemake distributes work across the threads you provide.

```bash
plaswrap classify -h
```

Key arguments:
- `-i` input FASTA directory
- `-o` output directory
- `-d` database root
- `--tools` tools to run (default: all)
- `-t` total cores
- `-s` split cores into N jobs (per‑job threads = cores/N)

## 2. Refinement
Uses classification outputs to identify high‑confidence plasmids.

You can control:
- **Minimum tools required** (k‑of‑n)
- **Score threshold** (applied to PlasX and PlasClass)
- **Mode**:  
  - *balance*: ≥3/4 tools, score ≥0.75  
  - *precision*: 4/4 tools, score ≥0.90

Outputs:
- UpSet plot of tool intersections
- Per‑sample TSV + merged TSV
- `plasmids/` folder containing predicted plasmid contigs

Example help:
```bash
plaswrap refine -h
```

![Upset plot](https://raw.githubusercontent.com/braddmg/images/main/venn_plasmids_upset.png)

## 3. Host taxonomic assignment
`GetTaxa` infers plasmid host taxonomy using HOTSPOT and optionally computes abundance using CoverM if FASTQ files are provided.

Outputs include:
- HOTSPOT results
- Corrected taxonomy table (phylum → species)
- Krona interactive plot
- (Optional) abundance matrix

Example:
```bash
plaswrap GetTaxa -h
```

# References
- Eren et al. (2021) *Nature Microbiology*
- Yu et al. (2024) *Nature Microbiology*
- Tian et al. (2024) *Briefings in Bioinformatics*
- Pellow et al. (2020) *PLoS Comput Biol*
- Schwengers et al. (2020) *Microbial Genomics*
- Ji et al. (2023) *Bioinformatics*
- Aroney et al. (2025) *Bioinformatics*
