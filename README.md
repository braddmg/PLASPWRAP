# PLASPWRAP
PLASWRAP is pipeline for plasmidomic analysis, which identify high-confidence palsmid contigs from metagenomic datasets and assign taxonomy using different tools


# Download the rep
```bash
git clone https://github.com/braddmg/PLASPWRAP
cd PLASWRAP
```
# run script to install environments

```bash
bash install_plaswrap.sh
```
# Activate plaswrap and download databases
Select the destination folder with -d and the number of threads to use -t
```bash
conda activate plaswrap
bash download_data.sh -d ~/databases/plaswrap -t 16
```
# Test the installation 
```bash
plaswrap --help
plaswrap classify -h
```
