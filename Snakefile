import fnmatch
import os
import snakemake.utils

from builds import prepare_builds

shell.prefix("source activate janus_python2; ")
configfile: "config.json"
localrules: prepare_virus_lineage, download, clean
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
        "segment"
    ]

    build = BUILDS[wildcards.name]
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
    return BUILDS[wildcards.name].get("process", "")

#
# Determine which builds to create.
#

BUILDS = prepare_builds(config["builds"])

# Filter builds by command line constraints. Filters are defined by
# comma-delimited wildcard patterns (e.g., "flu_*,zika").
if "filters" in config:
    # Find builds that match filters.
    build_names = list(BUILDS.keys())
    filters = config["filters"].split(",")
    included_builds = [build_name for build_name in build_names
                       if any([fnmatch.fnmatch(build_name, pattern) for pattern in filters])]

    # Remove builds that don't match filters.
    for build_name in build_names:
        if build_name not in included_builds:
            del BUILDS[build_name]

#
# Prepare and process viruses by lineage.
#

rule all:
    input: ["augur/%s/auspice/%s_meta.json" % (build["virus"], name) for name, build in BUILDS.items()]

rule process_virus_lineage:
    input: "augur/{virus}/prepared/{name}.json"
    output: "augur/{virus}/auspice/{name}_meta.json"
    log: "log/process_{name}.log"
    benchmark: "benchmarks/process_{name}.txt"
    params: arguments=_get_process_arguments
    shell: """cd augur/{wildcards.virus} && python {wildcards.virus}.process.py \
                  -j {SNAKEMAKE_DIR}/{input} {params.arguments} &> {SNAKEMAKE_DIR}/{log}"""

rule prepare_virus_lineage:
    output: "augur/{virus}/prepared/{name}.json"
    log: "log/prepare_{name}.log"
    benchmark: "benchmarks/prepare_{name}.txt"
    params: arguments=_get_prepare_arguments
    shell: """cd augur/{wildcards.virus} && python {wildcards.virus}.prepare.py \
                  --file_prefix {wildcards.name} \
                  {params.arguments} &> {SNAKEMAKE_DIR}/{log}"""

rule download:
    run:
        viruses = list(set([build["virus"] for build in BUILDS.values()]))
        for virus in viruses:
            print("Downloading data for %s" % virus)
            shell("cd fauna && python download_all.py --virus %s --sequences --titers" % virus)

rule clean:
    run:
        viruses = list(set([build["virus"] for build in BUILDS.values()]))
        for virus in viruses:
            shell("rm -rf augur/{virus}/prepared/*".format(virus=virus))
            shell("rm -rf augur/{virus}/processed/*".format(virus=virus))
            shell("rm -rf augur/{virus}/auspice/*".format(virus=virus))
