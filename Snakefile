import fnmatch
import os
import snakemake.utils

from builds import prepare_builds

shell.prefix("source activate janus_python2; ")
configfile: "config.json"
localrules: prepare_virus_lineage, download, clean, push
wildcard_constraints:
    virus="[a-zA-Z0-9]+"

# Set snakemake directory
SNAKEMAKE_DIR = os.path.dirname(workflow.snakefile)

# Create the cluster log directory.
snakemake.utils.makedirs("log/cluster")

#
# Functions to prepare builds from config.
#

def _get_prepare_arguments(wildcards):
    """Build a string of command line arguments to run the given build through
    augur's prepare step.
    """
    params = [
        "lineage",
        "resolution",
        "segments"
    ]

    build = BUILDS[wildcards.stem]
    arguments = []
    for param in params:
        if param in build:
            arguments.append("--%s %s" % (param, build[param]))

    if "prepare" in build:
        arguments.append(build["prepare"])

    return " ".join(arguments)

def _get_process_arguments(wildcards):
    """Build a string of command line arguments to run the given build through
    augur's process step.
    """
    return BUILDS[wildcards.stem].get("process", "")

#
# Determine which builds to create.
#

BUILDS = prepare_builds(config["builds"])

# Filter builds by command line constraints. Filters are defined by
# comma-delimited wildcard patterns (e.g., "flu_*,zika").
if "filters" in config:
    # Find builds that match filters.
    build_stems = list(BUILDS.keys())
    filters = config["filters"].split(",")
    included_builds = [build_stem for build_stem in build_stems
                       if any([fnmatch.fnmatch(build_stem, pattern) for pattern in filters])]

    # Remove builds that don't match filters.
    for build_stem in build_stems:
        if build_stem not in included_builds:
            del BUILDS[build_stem]

print("Found the following %i builds:" % len(BUILDS))
for build_stem in BUILDS:
    print(" - %s" % build_stem)

#
# Prepare and process viruses by lineage.
#

OUTPUT_FILES = ["augur/builds/%s/auspice/%s_meta.json" % (build["virus"], stem)
                for stem, build in BUILDS.items()]

# Push all requested JSONs to a given S3 bucket.
rule push:
    input: OUTPUT_FILES
    params:
        bucket=config["s3_bucket"],
        paths=[path.replace("_meta", "_*") for path in OUTPUT_FILES]
    log: "log/s3_push.log"
    benchmark: "benchmarks/s3_push.txt"
    shell: "python augur/scripts/s3.py -v push {params.bucket} {params.paths} &> {log}"

rule all:
    input: OUTPUT_FILES

rule process_virus_lineage:
    input: "augur/builds/{virus}/prepared/{stem}.json"
    output: "augur/builds/{virus}/auspice/{stem}_meta.json"
    log: "log/process_{stem}.log"
    benchmark: "benchmarks/process_{stem}.txt"
    params: arguments=_get_process_arguments
    shell: """cd augur/builds/{wildcards.virus} && python {wildcards.virus}.process.py \
                  -j {SNAKEMAKE_DIR}/{input} {params.arguments} &> {SNAKEMAKE_DIR}/{log}"""

rule prepare_virus_lineage:
    output: "augur/builds/{virus}/prepared/{stem}.json"
    log: "log/prepare_{stem}.log"
    benchmark: "benchmarks/prepare_{stem}.txt"
    params: arguments=_get_prepare_arguments
    shell: """cd augur/builds/{wildcards.virus} && python {wildcards.virus}.prepare.py \
                  --file_prefix {wildcards.stem} \
                  {params.arguments} &> {SNAKEMAKE_DIR}/{log}"""

rule download:
    benchmark: "benchmarks/fauna_download.txt"
    log: "log/fauna_download.log"
    run:
        shell("rm -f {log}")
        viruses = list(set([build["virus"] for build in BUILDS.values()]))
        for virus in viruses:
            print("Downloading data for %s" % virus)
            shell("cd fauna && python download_all.py --virus %s --sequences --titers >> {SNAKEMAKE_DIR}/{log}" % virus)

rule clean:
    run:
        viruses = list(set([build["virus"] for build in BUILDS.values()]))
        for virus in viruses:
            shell("rm -rf augur/builds/{virus}/prepared/*".format(virus=virus))
            shell("rm -rf augur/builds/{virus}/processed/*".format(virus=virus))
            shell("rm -rf augur/builds/{virus}/auspice/*".format(virus=virus))
