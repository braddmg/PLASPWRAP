import re
import glob
import os
import pandas as pd
from Bio import SeqIO
from matplotlib_venn import venn3
import matplotlib.pyplot as plt

shell.executable("/bin/bash")

################################################################################
# 1) Load config and define mode
################################################################################
configfile: "config.yaml"

MODE = config.get("mode", "balance")
if MODE not in ("balance", "precision"):
    raise ValueError(f"Unknown mode in config.yaml: {MODE}")
PLATON_MODE = "accuracy" if MODE == "balance" else "specificity"

################################################################################
# 2) Global parameters
################################################################################
THREADS = int(config["threads"])
OUTDIR  = config["output_dir"]
DATADIR = config["data_dir"]
RUN     = config.get("run_tools", {})

DB_ROOT = config.get("db_root", "db")

ANVIO = config.get("anvio", {})
ANVIO_ENV = ANVIO.get("conda_env", "anvio-8")
COG_VERSION = ANVIO.get("cog_version", "COG20")
ANVIO_COG_DIR  = ANVIO.get("COG20",  os.path.join(DB_ROOT, COG_VERSION))
ANVIO_PFAM_DIR = ANVIO.get("Pfam_v32", os.path.join(DB_ROOT,"Pfam_v32"))

PLATON_ENV = "plaswrap"
PLATON_DB  = config.get("platon", {}).get("db", os.path.join(DB_ROOT, "platon", "db"))
PLASX_ENV  = config.get("plasx", {}).get("conda_env", "plasx")
PLASX_DB  = config.get("plasx", {}).get("db", os.path.join(DB_ROOT, "plasx", "PlasX_mmseqs_profiles"))
PLASX_M = config.get("plasx", {}).get("model", os.path.join(DB_ROOT, "plasx", "PlasX_coefficients_and_gene_enrichments.txt"))
GENE_CALLS_DIR   = os.path.join(OUTDIR, "anvio", "gene_calls")
COGS_PFAMS_DIR   = os.path.join(OUTDIR, "anvio", "annotations")
PLASMIDHUNTER_ENV = "plaswrap"

# PlasClass settings
PLASCLASS_ENV = config.get("plasclass", {}).get("conda_env", "plasclass")
PLASCLASS_DB  = config.get("plasclass", {}).get("db", DB_ROOT)
PLASCLASS_SCRIPT = os.path.join(PLASCLASS_DB, "plasclass", "classify_fasta.py")

os.makedirs(OUTDIR, exist_ok=True)
os.makedirs(os.path.join(OUTDIR, "anvio"), exist_ok=True)
os.makedirs(GENE_CALLS_DIR, exist_ok=True)
os.makedirs(COGS_PFAMS_DIR, exist_ok=True)
os.makedirs(os.path.join(OUTDIR, "plasx"), exist_ok=True)

################################################################################
# 3) Helper function to find FASTA
################################################################################
def get_fasta(wildcards):
    # Quitar cualquier ruta o extensión accidental
    sample_name = os.path.basename(wildcards.sample)
    sample_name = re.sub(r'\..*$', '', sample_name)  # quita extensión si la hubiera
    for ext in (".fasta", ".fa", ".fna"):
        path = os.path.join(DATADIR, f"{sample_name}{ext}")
        if os.path.exists(path):
            return path
    raise FileNotFoundError(f"No FASTA found for sample {sample_name}")

################################################################################
# 4) Gather samples
################################################################################
FASTA_FILES = sorted(
    glob.glob(os.path.join(DATADIR, "*.fasta")) +
    glob.glob(os.path.join(DATADIR, "*.fa")) +
    glob.glob(os.path.join(DATADIR, "*.fna"))
)
SAMPLES = [os.path.splitext(os.path.basename(f))[0] for f in FASTA_FILES]

################################################################################
# 5) Build final target list
################################################################################
final_outputs = []

# Reformat FASTA (used by all tools)
final_outputs += expand(f"{OUTDIR}/anvio/{{sample}}.fa", sample=SAMPLES)

# Tool-specific outputs
if RUN.get("plasx", False):
    final_outputs += expand(f"{OUTDIR}/plasx/{{sample}}-scores.txt", sample=SAMPLES)
    final_outputs += expand(f"{OUTDIR}/plasx/{{sample}}-reformat-report.txt", sample=SAMPLES)

if RUN.get("platon", False):
    final_outputs += expand(f"{OUTDIR}/platon/{{sample}}/.done", sample=SAMPLES)

if RUN.get("plasmidhunter", False):
    final_outputs += expand(f"{OUTDIR}/plasmidhunter/{{sample}}/.done", sample=SAMPLES)

if RUN.get("plasclass", False):
    final_outputs += expand(f"{OUTDIR}/plasclass/{{sample}}/.done", sample=SAMPLES)


rule all:
    input:
        final_outputs


################################################################################
# 6) Reformat FASTA
################################################################################
rule anvio_reformat:
    input:
        fasta = get_fasta
    output:
        fa     = f"{OUTDIR}/anvio/{{sample}}.fa",
        report = f"{OUTDIR}/anvio/{{sample}}-report.txt"
    threads: THREADS
    log: f"{OUTDIR}/anvio/{{sample}}.reformat.log"
    shell:
        r'''
        echo "[INFO] Reformatting {wildcards.sample}" >&2
        mkdir -p {OUTDIR}/anvio
        conda run -n {ANVIO_ENV} anvi-script-reformat-fasta {input.fasta} \
            -o {output.fa} -l 1000 --seq-type NT --simplify-names --prefix {wildcards.sample} \
            -r {output.report} 1>/dev/null 2> >(tee -a {log} >&2)
        '''

################################################################################
# 7) Anvi'o annotation (only if plasx)
################################################################################
rule anvio_gen_db:
    input: fa = rules.anvio_reformat.output.fa
    output: db = f"{OUTDIR}/anvio/{{sample}}.db"
    threads: THREADS
    log: f"{OUTDIR}/anvio/{{sample}}.gendb.log"
    shell: r'''
        echo "[INFO] Anvi'o gen-contigs-db {wildcards.sample}" >&2
        conda run -n {ANVIO_ENV} anvi-gen-contigs-database -f {input.fa} -o {output.db} -T {threads} \
            1>/dev/null 2> >(tee -a {log} >&2)
    '''

rule anvio_export_gene_calls:
    input:
        db = rules.anvio_gen_db.output.db,
    output: calls = f"{GENE_CALLS_DIR}/{{sample}}-gene-calls.txt"
    threads: THREADS
    log: f"{OUTDIR}/anvio/{{sample}}.gene_calls.log"
    shell: r'''
        echo "[INFO] Anvi'o export gene-calls {wildcards.sample}" >&2
        mkdir -p {GENE_CALLS_DIR}
        conda run -n {ANVIO_ENV} anvi-export-gene-calls --gene-caller prodigal -c {input.db} -o {output.calls} \
            1>/dev/null 2> >(tee -a {log} >&2)
    '''

rule anvio_run_cogs:
    input: db = rules.anvio_gen_db.output.db
    output: done = temp(f"{OUTDIR}/anvio/{{sample}}.cogs.done")
    threads: THREADS
    log: f"{OUTDIR}/anvio/{{sample}}.cogs.log"
    params: cog_version = COG_VERSION, cog_dir = ANVIO_COG_DIR
    shell: r'''
        echo "[INFO] Anvi'o run COGs {wildcards.sample}" >&2
        conda run -n {ANVIO_ENV} anvi-run-ncbi-cogs -T {threads} --cog-version {params.cog_version} \
            --cog-data-dir {params.cog_dir} -c {input.db} \
            1>/dev/null 2> >(tee -a {log} >&2)
        touch {output.done}
    '''

rule anvio_run_pfams:
    input: db = rules.anvio_gen_db.output.db
    output: done = temp(f"{OUTDIR}/anvio/{{sample}}.pfams.done")
    threads: THREADS
    log: f"{OUTDIR}/anvio/{{sample}}.pfams.log"
    params: pfam_dir = ANVIO_PFAM_DIR
    shell: r'''
        echo "[INFO] Anvi'o run Pfams {wildcards.sample}" >&2
        conda run -n {ANVIO_ENV} anvi-run-pfams -T {threads} --pfam-data-dir {params.pfam_dir} -c {input.db} \
            1>/dev/null 2> >(tee -a {log} >&2)
        touch {output.done}
    '''

rule anvio_export_functions:
    input:
        db = rules.anvio_gen_db.output.db,
        cogs_done  = rules.anvio_run_cogs.output.done,
        pfams_done = rules.anvio_run_pfams.output.done
    output: annot = f"{COGS_PFAMS_DIR}/{{sample}}-cogs-and-pfams.txt"
    threads: THREADS
    log: f"{OUTDIR}/anvio/{{sample}}.functions.log"
    params: sources = "COG20_FUNCTION,Pfam"
    shell: r'''
        echo "[INFO] Anvi'o export functions {wildcards.sample}" >&2
        mkdir -p {COGS_PFAMS_DIR}
        conda run -n {ANVIO_ENV} anvi-export-functions --annotation-sources {params.sources} \
            -c {input.db} -o {output.annot} \
            1>/dev/null 2> >(tee -a {log} >&2)
    '''

################################################################################
# 8) PLASX rules
################################################################################
rule plasx_denovo:
    input: gene_calls = rules.anvio_export_gene_calls.output.calls
    output: denovo = f"{OUTDIR}/plasx/{{sample}}-de-novo-families.txt"
    threads: THREADS
    log: f"{OUTDIR}/plasx/{{sample}}.plasx_denovo.log"
    params: db = PLASX_DB
    shell: r'''
        echo "[INFO] PLASX search_de_novo_families {wildcards.sample}" >&2
        mkdir -p {OUTDIR}/plasx
        conda run -n {PLASX_ENV} plasx search_de_novo_families \
            -g {input.gene_calls} -o {output.denovo} \
            --threads {threads} --splits 32 --overwrite -db {params.db} \
            1>/dev/null 2> >(tee -a {log} >&2)
    '''

rule plasx_predict:
    input:
        denovo     = rules.plasx_denovo.output.denovo,
        cogs_pfams = rules.anvio_export_functions.output.annot,
        gene_calls = rules.anvio_export_gene_calls.output.calls
    output: scores = f"{OUTDIR}/plasx/{{sample}}-scores.txt"
    threads: THREADS
    log: f"{OUTDIR}/plasx/{{sample}}.plasx_predict.log"
    params: model = PLASX_M
    shell: r'''
        echo "[INFO] PLASX predict {wildcards.sample}" >&2
        conda run -n {PLASX_ENV} plasx predict \
            -a {input.cogs_pfams} {input.denovo} \
            -g {input.gene_calls} -o {output.scores} --overwrite -m {params.model} \
            1>/dev/null 2> >(tee -a {log} >&2)
    '''

rule plasx_copy_reformat_report:
    input: report = rules.anvio_reformat.output.report
    output: copied = f"{OUTDIR}/plasx/{{sample}}-reformat-report.txt"
    log: f"{OUTDIR}/plasx/{{sample}}.copy_report.log"
    shell: r'''
        echo "[INFO] PLASX copy reformat report {wildcards.sample}" >&2
        cp {input.report} {output.copied} 1>/dev/null 2> >(tee -a {log} >&2)
    '''

################################################################################
# 9) PLATON
################################################################################
rule platon:
    input: fa = rules.anvio_reformat.output.fa
    output:
        folder = directory(f"{OUTDIR}/platon/{{sample}}"),
        done   = f"{OUTDIR}/platon/{{sample}}/.done"
    threads: THREADS
    log: f"{OUTDIR}/platon/{{sample}}.log"
    params: mode = PLATON_MODE, db = PLATON_DB
    shell: r'''
        echo "[INFO] PLATON {wildcards.sample} ({params.mode})" >&2
        mkdir -p {output.folder}
        conda run -n {PLATON_ENV} platon --db {params.db} --prefix {wildcards.sample} \
            --output {output.folder} --mode {params.mode} --meta --threads {threads} \
            {input.fa} 1>/dev/null 2> >(tee -a {log} >&2)
        touch {output.done}
    '''

################################################################################
# 10) PlasmidHunter
################################################################################
rule plasmidhunter:
    input: fa = rules.anvio_reformat.output.fa
    output:
        folder = directory(f"{OUTDIR}/plasmidhunter/{{sample}}"),
        done   = f"{OUTDIR}/plasmidhunter/{{sample}}/.done"
    threads: THREADS
    log: f"{OUTDIR}/plasmidhunter/{{sample}}.log"
    shell: r'''
        echo "[INFO] PlasmidHunter {wildcards.sample}" >&2
        mkdir -p {output.folder}
        conda run -n {PLASMIDHUNTER_ENV} plasmidhunter -i {input.fa} -o {output.folder} -c {threads} \
            1>/dev/null 2> >(tee -a {log} >&2)
        touch {output.done}
    '''

################################################################################
# PlasClass
################################################################################
rule plasclass:
    input:
        fa = rules.anvio_reformat.output.fa
    output:
        folder = directory(f"{OUTDIR}/plasclass/{{sample}}"),
        done   = f"{OUTDIR}/plasclass/{{sample}}/.done"
    threads: THREADS
    log: f"{OUTDIR}/plasclass/{{sample}}.log"
    params:
        script = PLASCLASS_SCRIPT
    shell: r'''
        echo "[INFO] PlasClass {wildcards.sample}" >&2
        mkdir -p {output.folder}
        conda run -n {PLASCLASS_ENV} python {params.script} -f {input.fa} -o {output.folder} -p {threads} \
            1>/dev/null 2> >(tee -a {log} >&2)
        touch {output.done}
    '''
