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
```bash
singulairty exec plaswrap-0.1.4.sif plaswrap --help
usage: plaswrap [-h] {classify,refine,GetTaxa} ...

PLASWRAP launcher

positional arguments:
  {classify,refine,GetTaxa}
    classify            Run the classification pipeline (snakemake)
    refine              Refine potential plasmidic contigs
    GetTaxa             Run host taxonomy identification and (if selected) calculate coverage abundance

options:
  -h, --help            show this help message and exit
```
```

## Databases
Download required databases (choose download folder with `-d` and threads with `-t`):
```bash
singularity exec plaswrap-0.1.4.sif download_data.sh -d ~/databases/plaswrap -t 64
```

## Manual installation (conda)
If not using Singularity, run the installer to create all required environments: plaswrap, anvio‑8, plasx, platon, plasclass, and hotspot.
```bash
bash install_plaswrap.sh --force #force will remove environments with same names and reinstall them.
```
Then activate and download databases:
```bash
conda activate plaswrap
bash download_data.sh -d ~/databases/plaswrap -t 64
```

# Usage

## 1. Classification
Runs a Snakemake workflow using four tools: PlasX, PlasClass, Platon, and PlasmidHunter. You may choose a subset of tools.

Each FASTA file in the input directory is treated as one sample. Snakemake distributes work across the threads you provide.

```bash
plaswrap classify -h

usage: plaswrap classify [-h] [-i DATA_DIR] [-o OUTPUT_DIR] [-d DB_ROOT] [-m MODE] [-s SPLITS] [-t CORES] [--tools TOOLS] [-n]
                         [--run-incomplete] [--unlock]

options:
  -h, --help            show this help message and exit
  -i DATA_DIR, --input-dir DATA_DIR
                        Input FASTA data directory
  -o OUTPUT_DIR, --output-dir OUTPUT_DIR
                        Output directory
  -d DB_ROOT, --db DB_ROOT
                        Root folder containing databases
  -m MODE, --mode MODE  Platon mode: sensitivity,accuracy,specificity (default: accuracy, see
                        https://github.com/oschwengers/platon)
  -s SPLITS, --splits SPLITS
                        Split total cores across N parallel jobs; per-job threads= cores/splits
  -t CORES, --threads CORES
                        Total scheduler cores for Snakemake
  --tools TOOLS         Comma-separated tools to run (default: "all"). Options: plasx, platon, plasmidhunter, plasclass
  -n, --dry-run         Show what would run without executing
  --run-incomplete      re-run incomplete job
  --unlock              unlock snakemake work

```

## 2. Refinement
Uses classification outputs to identify high‑confidence plasmids.

Outputs:
- UpSet plot of tool intersections
- Per‑sample TSV + merged TSV
- `plasmids/` folder containing predicted plasmid contigs
- 
Example help:
```bash
usage: plaswrap refine [-h] [-i INPUT_DIR] [-o OUTPUT_DIR] [-m {balance,precision}] [--threshold THRESHOLD]
                       [--min-tools MIN_TOOLS] [--run-tools RUN_TOOLS] [--samples SAMPLES [SAMPLES ...]]

options:
  -h, --help            show this help message and exit
  -i INPUT_DIR, --input-dir INPUT_DIR
                        Input directory where classify outputs exist
  -o OUTPUT_DIR, --output-dir OUTPUT_DIR
                        Directory to write refining results (default: same as --input-dir)
  -m {balance,precision}, --mode {balance,precision}
                        In balance mode, plasmids are considered valid if identified by at least 3 out of 4 tools
                        (plasx/plasclass score = 0.75), whereas in precision mode, plasmids must be identified by all 4 tools
                        (score = 0.9)
  --threshold THRESHOLD
                        Manual threshold for plasclass and plasx (overrides mode selection)
  --min-tools MIN_TOOLS
                        Manual number of tools required (overrides mode selection)
  --run-tools RUN_TOOLS
                        Comma-separated tools enabled
  --samples SAMPLES [SAMPLES ...]
                        List of sample names; if omitted, attempts to infer from <outdir>/anvio/*.fa
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
usage: plaswrap GetTaxa [-h] -i INPUT_DIR -d DATABASE -o OUTPUT_DIR [-t THREADS] [--fastq-files FASTQ_DIR]
                        [--method COVERM_METHOD] [--accurate]

options:
  -h, --help            show this help message and exit
  -i INPUT_DIR, --input-dir INPUT_DIR
                        Input folder
  -d DATABASE, --database DATABASE
                        Databases root
  -o OUTPUT_DIR, --output-dir OUTPUT_DIR
                        Output directory
  -t THREADS, --threads THREADS
                        Threads
  --fastq-files FASTQ_DIR
                        Folder with paired FASTQs. (*[1,2].fastq, *[1,2].fastq.gz, *[1,2].fq or *[1,2].fq.gz
  --method COVERM_METHOD
                        CoverM contig method (default: rpkm), see https://wwood.github.io/CoverM/coverm-contig.html
  --accurate            Enable HOTSPOT accurate (Monte Carlo) mode, see https://github.com/Orin-beep/HOTSPOT
```

# References
- Eren et al. (2021) *Nature Microbiology*
- Yu et al. (2024) *Nature Microbiology*
- Tian et al. (2024) *Briefings in Bioinformatics*
- Pellow et al. (2020) *PLoS Comput Biol*
- Schwengers et al. (2020) *Microbial Genomics*
- Ji et al. (2023) *Bioinformatics*
- Aroney et al. (2025) *Bioinformatics*
