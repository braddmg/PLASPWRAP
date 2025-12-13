# PLASWRAP
A pipeline for plasmidomic analysis that detects high‑confidence plasmid contigs from metagenomic assemblies and assigns taxonomy using multiple tools.

![PLASWRAP flow](https://raw.githubusercontent.com/braddmg/images/main/plaswrap_flow.png)

## Download
```bash
git clone https://github.com/braddmg/PLASWRAP
cd PLASWRAP
```

# Installation
PLASWRAP is easiest to use through Singularity because it relies on multiple conda environments.

## Singularity
Download the `.sif` image 
```bash
wget https://zenodo.org/records/17915106/files/plaswrap-0.1.4.sif?download=1 -O plaswrap-0.1.4.sif
```

and run:
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

## Databases
Download required databases (choose download folder with `-d` and threads with `-t`):
```bash
singularity exec plaswrap-0.1.4.sif download_data.sh -d ~/databases/plaswrap -t 64
```

## Manual installation (conda)
If not using Singularity or docker, run the installer to create all required environments: plaswrap, anvio‑8, plasx, platon, plasclass, and hotspot.
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
Each FASTA file in the input directory is treated as one sample. 

Snakemake can distribute work across the CPU threads you provide by using the `-t` and `-s` options. <br/>
For example, if you have 64 cores available and want to allocate up to 16 cores per job, you can run Snakemake with `-t 64` and specify `-s 4`. <br/>
This will run up to four jobs simultaneously, with each job using 16 threads. <br/>
If you do not specify -s, each job will use all the available threads.

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
Outputs:
- UpSet plot of tool intersections
- Per‑sample TSV + merged TSV
- `plasmids/` folder containing predicted plasmidic contigs

![Upset plot](https://raw.githubusercontent.com/braddmg/images/main/venn_plasmids_upset.png)

## 3. Host taxonomic assignment
`GetTaxa` infers plasmid host taxonomy using HOTSPOT and optionally computes abundance using CoverM if FASTQ files are provided.

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

Outputs include:
- HOTSPOT results
- Corrected taxonomy table (phylum → species)
- Krona interactive plot
- (Optional) abundance matrix

# References
- Eren, A. M., Kiefl, E., Shaiber, A., Veseli, I., Miller, S. E., Schechter, M. S., ... & Willis, A. D. (2021). Community-led, integrated, reproducible multi-omics with anvi’o. Nature microbiology, 6(1), 3-6.<br/>
- Yu, M. K., Fogarty, E. C., & Eren, A. M. (2024). Diverse plasmid systems and their ecology across human gut metagenomes revealed by PlasX and MobMess. Nature Microbiology, 9(3), 830-847.<br/>
- Tian, R., Zhou, J., & Imanian, B. (2024). PlasmidHunter: accurate and fast prediction of plasmid sequences using gene content profile and machine learning. Briefings in Bioinformatics, 25(4).<br/>
- Pellow, D., Mizrahi, I., & Shamir, R. (2020). PlasClass improves plasmid sequence classification. PLoS computational biology, 16(4), e1007781.<br/>
- Schwengers, O., Barth, P., Falgenhauer, L., Hain, T., Chakraborty, T., & Goesmann, A. (2020). Platon: identification and characterization of bacterial plasmid contigs in short-read draft assemblies exploiting protein sequence-based replicon distribution scores. Microbial genomics, 6(10), e000398.<br/>
- Ji, Y., Shang, J., Tang, X., & Sun, Y. (2023). HOTSPOT: hierarchical host prediction for assembled plasmid contigs with transformer. Bioinformatics, 39(5), btad283.<br/>
- Aroney, S. T., Newell, R. J., Nissen, J. N., Camargo, A. P., Tyson, G. W., & Woodcroft, B. J. (2025). CoverM: read alignment statistics for metagenomics. Bioinformatics, 41(4), btaf147.<br/>
