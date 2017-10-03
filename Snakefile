import itertools
import fnmatch
import os
import snakemake.utils
import string

shell.prefix("source activate janus_python2; ")
configfile: "config.json"
wildcard_constraints:
    virus="[a-zA-Z0-9]+"

# Set snakemake directory
SNAKEMAKE_DIR = os.path.dirname(workflow.snakefile)

# Create the cluster log directory.
snakemake.utils.makedirs("log/cluster")

#
# Functions to prepare builds from config.
#

def parse_variables_from_template(template):
    """Parses variables from template string and returns list of variable names.

    >>> parse_variables_from_template("flu_h3n2")
    []
    >>> parse_variables_from_template("{virus}")
    ['virus']
    >>> parse_variables_from_template("{virus}_{lineage}")
    ['virus', 'lineage']
    """
    formatter = string.Formatter()
    return [item[1]
            for item in list(formatter.parse(template))
            if item[1] is not None]

def prepare_builds(builds):
    """Returns a list of complete build definitions for a given list of build templates.

    >>> builds = prepare_builds([{"name": "{virus}", "virus": ["zika"]}])
    >>> [sorted(build.items()) for name, build in builds.items()]
    [[('name', 'zika'), ('virus', 'zika')]]
    >>> builds = prepare_builds([{"name": "{virus}_{lineage}", "virus": ["zika"], "lineage": ["one", "two"]}])
    >>> sorted(builds.keys())
    ['zika_one', 'zika_two']
    """
    new_builds = {}

    for build in builds:
        # Find variables.
        variables = set(parse_variables_from_template(build["name"]))
        for key in build:
            if isinstance(build[key], list):
                variables.add(key)
        variables = list(variables)

        # Find non-variables.
        non_variables = set(build.keys()) - set(variables + ["name"])

        # Iterate through combinations of variables in nested for loop.
        variable_product = list(itertools.product(*[build[variable] for variable in variables]))
        named_variable_product = [dict(zip(variables, product)) for product in variable_product]

        for product in named_variable_product:
            # Create a dictionary from the current combination of variables
            new_build = product

            # Create a new name from the parent name field
            new_build["name"] = build["name"].format(**product)

            # String format each non-variable with the base dictionary and add to new dictionary
            for non_variable in non_variables:
                new_build[non_variable] = build[non_variable].format(**product)

            # Create new build entry indexed by name with variable and non-variable dictionaries merged
            new_builds[new_build["name"]] = new_build

    return new_builds

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
# Prepare outputs.
#

# Determine which builds to create.
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

rule all:
    input: ["augur/%s/auspice/%s_meta.json" % (build["virus"], name) for name, build in BUILDS.items()]

#
# Prepare and process viruses by lineage.
#

rule process_virus_lineage:
    input: "augur/{virus}/prepared/{name}.json"
    output: "augur/{virus}/auspice/{name}_meta.json"
    log: "log/process_{name}.log"
    params: arguments=_get_process_arguments
    benchmark: "benchmarks/process/{name}.txt"
    shell: """cd augur/{wildcards.virus} && python {wildcards.virus}.process.py \
                  -j {SNAKEMAKE_DIR}/{input} {params.arguments} &> {SNAKEMAKE_DIR}/{log}"""

rule prepare_virus_lineage:
    output: "augur/{virus}/prepared/{name}.json"
    log: "log/prepare_{name}.log"
    params: arguments=_get_prepare_arguments
    benchmark: "benchmarks/prepare/{name}.txt"
    shell: """cd augur/{wildcards.virus} && python {wildcards.virus}.prepare.py \
                  --file_prefix {wildcards.name} \
                  {params.arguments} &> {SNAKEMAKE_DIR}/{log}"""

rule download:
    run:
        viruses = list(set([build["virus"] for build in BUILDS.values()]))
        for virus in viruses:
            print("Downloading data for %s" % virus)
            shell("cd fauna && python download_all.py --virus %s --sequences --titers" % virus)
