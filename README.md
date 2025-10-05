# PLASWRAP
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

# Refining

After running all tools, use the refine function with the classify output as its only input.<br/>
You can set:<br/>

- the minimum number of tools that must agree for a contig to be kept as a plasmid (k-of-n), and<br/>

- a single score threshold applied to both PLASX and PlasClass.<br/>

Defaults:<br/>

- Balance mode: keeps contigs classified by 3/4 tools with a score ≥ 0.75.<br/>

- High-precision mode: keeps contigs classified by 4/4 tools with a score ≥ 0.90.<br/>

Outputs:<br/>

- An UpSet plot summarizing per-tool and intersection results,<br/>

- A TSV with assignment results for each sample, plus a merged TSV across all samples, and<br/>

- A plasmids/ folder containing the potential plasmid contigs per sample.<br/>

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
Upset plot example:
![Upset plot](https://raw.githubusercontent.com/braddmg/images/main/venn_plasmids_upset.png)
# Host Taxonomic Assigment
Use the GetTaxa function to infer the potential host taxonomy of plasmids by calling HOTSPOT. It creates an output folder containing:<br/>

- HOTSPOT taxonomy results, <br/>

- a corrected CSV with full plasmid taxonomy (phylum → species), and <br/>

- an interactive Krona plot of the taxonomy. <br/>

You can enable HOTSPOT’s accurate mode if desired. <br/>
If you also provide a folder with FASTQ files, the function will estimate contig abundance across samples using CoverM. You may choose the abundance method (e.g., RPKM, TPM). Other CoverM options are fixed in this wrapper; however, because CoverM is installed in the plaswrap environment, you can run it independently to customize additional parameters.

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
- Eren, A. M., Kiefl, E., Shaiber, A., Veseli, I., Miller, S. E., Schechter, M. S., ... & Willis, A. D. (2021). Community-led, integrated, reproducible multi-omics with anvi’o. Nature microbiology, 6(1), 3-6.<br/>
- Yu, M. K., Fogarty, E. C., & Eren, A. M. (2024). Diverse plasmid systems and their ecology across human gut metagenomes revealed by PlasX and MobMess. Nature Microbiology, 9(3), 830-847.<br/>
- Tian, R., Zhou, J., & Imanian, B. (2024). PlasmidHunter: accurate and fast prediction of plasmid sequences using gene content profile and machine learning. Briefings in Bioinformatics, 25(4).<br/>
- Pellow, D., Mizrahi, I., & Shamir, R. (2020). PlasClass improves plasmid sequence classification. PLoS computational biology, 16(4), e1007781.<br/>
- Schwengers, O., Barth, P., Falgenhauer, L., Hain, T., Chakraborty, T., & Goesmann, A. (2020). Platon: identification and characterization of bacterial plasmid contigs in short-read draft assemblies exploiting protein sequence-based replicon distribution scores. Microbial genomics, 6(10), e000398.<br/>
- Ji, Y., Shang, J., Tang, X., & Sun, Y. (2023). HOTSPOT: hierarchical host prediction for assembled plasmid contigs with transformer. Bioinformatics, 39(5), btad283.<br/>
- Aroney, S. T., Newell, R. J., Nissen, J. N., Camargo, A. P., Tyson, G. W., & Woodcroft, B. J. (2025). CoverM: read alignment statistics for metagenomics. Bioinformatics, 41(4), btaf147.<br/>
