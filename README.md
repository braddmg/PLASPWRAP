# PLASPWRAP
PLASWRAP is a pipeline for plasmidomic analysis that identifies high-confidence plasmid contigs from metagenomic datasets and assigns taxonomy using different tools.
![PLASWRAP flow](https://raw.githubusercontent.com/braddmg/images/main/plaswrap_flow.png)

# Download the repository
```bash
git clone https://github.com/braddmg/PLASWRAP
cd PLASWRAP
```
# Run the installation script

```bash
bash install_plaswrap.sh --force #force option will remove any existing environments named anvio-8, plasx, platon, plasclass, and hotspot, and create new ones
```
# Activate PLASWRAP and download databases
Select the destination folder with "-d" and the number of threads with "-t"
```bash
conda activate plaswrap
bash download_data.sh -d ~/databases/plaswrap -t 16
```
# Classify 
The "classify" function runs a Snakemake workflow to assign plasmid contigs using four tools: plasx, plasclass, platon, and plasmidhunter. You can choose which tools to run instead of using all four. <br/> Provide the database path you configured with the earlier download script. The input may include multiple FASTA files; each file is treated as an independent sample. <br/>
Snakemake can distribute the threads you specify across parallel jobs (across samples and/or steps), allowing multiple tasks to run concurrently.
```bash
plaswrap --help
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

