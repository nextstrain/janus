import os
import sys

shell.prefix("source activate augur; ")
configfile: "config.json"

# Set snakemake directory
SNAKEMAKE_DIR = os.path.dirname(workflow.snakefile)

VIRUSES = ("flu",)
LINEAGES = ("h3n2",)
SEGMENTS = ("ha",)
RESOLUTIONS = ("3y",)

rule all:
    input: expand("augur/{virus}/auspice/{virus}_{lineage}_{segment}_{resolution}_meta.json", virus=VIRUSES, lineage=LINEAGES, segment=SEGMENTS, resolution=RESOLUTIONS)

rule process_virus:
    input: "augur/{virus}/prepared/{virus}_{lineage}_{segment}_{resolution}.json"
    output: "augur/{virus}/auspice/{virus}_{lineage}_{segment}_{resolution}_meta.json"
    shell: "cd augur/{wildcards.virus} && python {wildcards.virus}.process.py -j {SNAKEMAKE_DIR}/{input} --no_mut_freqs --no_tree_freqs"

def _get_viruses_per_month(wildcards):
    """Return the number of viruses per month for the given virus, lineage, and
    resolution with a default value returned when no configuration is defined.
    """
    return config["viruses"][wildcards.virus]["viruses_per_month"].get(wildcards.resolution, 10)

rule prepare_virus:
    input:
        sequences="fauna/data/{virus}_{lineage}_{segment}.fasta",
        titers="fauna/data/{virus}_{lineage}_titers.tsv"
    output: "augur/{virus}/prepared/{virus}_{lineage}_{segment}_{resolution}.json"
    params: viruses_per_month=_get_viruses_per_month
    shell: """cd augur/{wildcards.virus} && python {wildcards.virus}.prepare.py --lineage {wildcards.lineage} \
              --resolution {wildcards.resolution} --segments {wildcards.segment} --sampling even \
              --viruses_per_month_seq {params.viruses_per_month} --titers {SNAKEMAKE_DIR}/{input.titers} \
              --sequences {SNAKEMAKE_DIR}/{input.sequences}"""

rule download_virus_titers:
    output: "fauna/data/{virus}_{lineage}_titers.tsv"
    shell: "cd fauna && python tdb/download.py -db tdb -v {wildcards.virus} --subtype {wildcards.lineage} --select assay_type:hi --fstem {wildcards.virus}_{wildcards.lineage}"

def _get_locus(wildcards):
    return wildcards.segment.upper()

rule download_virus_sequences:
    output: "fauna/data/{virus}_{lineage}_{segment}.fasta"
    params: locus=_get_locus
    shell: "cd fauna && python vdb/flu_download.py -db vdb -v {wildcards.virus} --select locus:{params.locus} lineage:seasonal_{wildcards.lineage} --fstem {wildcards.virus}_{wildcards.lineage}_{wildcards.segment}"
