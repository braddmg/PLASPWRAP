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
# Test the installation 
```bash
plaswrap --help
plaswrap classify -h
```

