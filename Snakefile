from collections import defaultdict
import glob
import json
import os
import shlex
import snakemake.utils
from snakemake.logging import logger
import sys

onsuccess:
    if "SLACK_WEBHOOK_URL" in os.environ:
        builds = list(_get_virus_builds(config).keys())
        message = {"text": "Augur builds for %s completed successfully." % ", ".join(builds)}
        shell("""curl -X POST -H 'Content-type: application/json' --data '{%s}' $SLACK_WEBHOOK_URL""" % json.dumps(message))

onerror:
    if "SLACK_WEBHOOK_URL" in os.environ:
        builds = list(_get_virus_builds(config).keys())
        message = {"text": "One or more of the following augur builds failed: %s." % ", ".join(builds)}
        shell("""curl -X POST -H 'Content-type: application/json' --data '{%s}' $SLACK_WEBHOOK_URL""" % json.dumps(message))

shell.prefix("source activate janus_python2; ")
configfile: "config.json"
localrules: download_virus_lineage_titers, download_virus_lineage_sequences, download_complete_virus_sequences, clean
wildcard_constraints:
    virus="[a-zA-Z0-9]+"

# Set snakemake directory
SNAKEMAKE_DIR = os.path.dirname(workflow.snakefile)

# Create the cluster log directory.
snakemake.utils.makedirs("log/cluster")

# Warn user about missing environment variables and exit if any are missing.
EXPECTED_ENV_VARIABLES = ["RETHINK_HOST", "RETHINK_AUTH_KEY", "NCBI_EMAIL"]
MISSING_ENV_VARIABLES = []
for variable in EXPECTED_ENV_VARIABLES:
    if not variable in os.environ:
        MISSING_ENV_VARIABLES.append(variable)

if len(MISSING_ENV_VARIABLES) > 0:
    logger.warning("Missing environment variables: %s" % ", ".join(MISSING_ENV_VARIABLES))
    sys.exit(1)

#
# Helper functions
#

def _get_virus_builds(config):
    viruses = defaultdict(list)

    if "builds" in config:
        # If the build config is user-defined on the command line, it will be a
        # comma-delimited string of viruses and lineages. If it is defined in
        # the config file, it will be a list.
        if isinstance(config["builds"], str):
            builds = config["builds"].replace(" ", "").split(",")
        else:
            builds = config["builds"]

        for build in builds:
            # Specific lineages are requested in the format of
            # "virus/lineage". In the absence of specific lineage requests, use
            # all defined lineages in the configuration file or default to
            # "all".
            if "/" in build:
                virus, lineage = build.split("/")
                viruses[virus].append(lineage)
            elif "lineages" in config["viruses"][build]:
                viruses[build] = config["viruses"][build]["lineages"]
            else:
                viruses[build].append("all")

    return viruses


def _get_json_outputs_by_virus(config):
    """Prepare a list of outputs for all combination of viruses, lineages, and
    segments defined in the configuration.
    """
    outputs = []
    viruses = _get_virus_builds(config)

    for virus, lineages in viruses.items():
        virus_config = config["viruses"][virus]
        for lineage in lineages:
            for resolution in virus_config.get(lineage, {}).get("resolutions", ["all"]):
                for segment in virus_config.get(lineage, {}).get("segments", ["all"]):
                    outputs.append("augur/%s/auspice/%s_%s_%s_%s_meta.json" % (virus, virus, lineage, segment, resolution))

    return outputs

def _get_viruses_per_month(wildcards):
    """Return the number of viruses per month for the given virus, lineage, and
    resolution with a default value returned when no configuration is defined.

    Check first for lineage- and resolution-specific viruses per month (as with
    flu). Then check for virus-specific viruses per month. If no value has been
    defined, return 0.
    """
    virus_config = config["viruses"][wildcards.virus]
    if (hasattr(wildcards, "lineage") and
        wildcards.lineage in virus_config and
        "viruses_per_month" in virus_config[wildcards.lineage] and
        wildcards.resolution in virus_config[wildcards.lineage]["viruses_per_month"]):
        viruses_per_month = virus_config[wildcards.lineage]["viruses_per_month"][wildcards.resolution]
    elif "viruses_per_month" in virus_config:
        viruses_per_month = virus_config["viruses_per_month"]
    else:
        viruses_per_month = 0

    return viruses_per_month

def _get_lineage_argument_by_virus_lineage(wildcards):
    """Return the lineage argument to use for the given virus and lineage. The
    default is not to define any argument.
    """
    if hasattr(wildcards, "lineage") and wildcards.lineage != "all":
        return "--lineage %s" % wildcards.lineage
    else:
        return ""

def _get_resolution_argument_by_virus_lineage(wildcards):
    """Return the resolution to use for the given virus and lineage. The
    default is not to define any resolution argument.
    """
    if hasattr(wildcards, "resolution") and wildcards.resolution != "all":
        return "--resolution %s" % wildcards.resolution
    else:
        return ""

def _get_sampling_argument_by_virus_lineage(wildcards):
    """Return the type of sampling to use for the given virus and lineage. The
    default is not to define any sampling argument.
    """
    sampling = config["viruses"][wildcards.virus].get(wildcards.lineage, {}).get("sampling")
    if sampling is not None:
        return "--sampling %s" % sampling
    else:
        return ""

def _get_segment_argument_by_virus_lineage(wildcards):
    """Return the segment to use for the given virus and lineage. The default is to
    not define any segment.
    """
    if hasattr(wildcards, "segment") and wildcards.segment != "all":
        return "--segments %s" % wildcards.segment
    else:
        return ""

def _get_fauna_virus(wildcards):
    """Returns the name fauna uses for a given virus.
    """
    # TODO: update fauna to encapsulate inconsistent virus naming conventions.
    if wildcards.virus == "avian":
        virus = "h7n9"
    else:
        virus = wildcards.virus

    return virus.lower()

def _get_locus_argument(wildcards):
    """If the current virus/lineage has a defined segment, uppercase the requested
    segment name for fauna.
    """
    if hasattr(wildcards, "segment") and wildcards.segment != "all":
        return "--select locus:%s" % wildcards.segment.upper()
    else:
        return ""

def _get_fauna_lineage_argument(wildcards):
    """If the current virus has a defined lineage and the virus is seasonal flu,
    prepend the 'seasonal_' prefix to seasonal flu strains for fauna when
    necessary.
    """
    # TODO: handle virus-specific logic inside fauna itself.
    if wildcards.virus == "flu" and wildcards.lineage in ["h3n2", "h1n1pdm", "vic", "yam"]:
        fauna_lineage = "seasonal_%s" % wildcards.lineage
    elif wildcards.virus == "avian":
        fauna_lineage = None
    elif wildcards.lineage != "all":
        fauna_lineage = wildcards.lineage
    else:
        fauna_lineage = None

    if wildcards.virus == "dengue":
        # fauna download scripts for dengue expect a filter like "--select serotype:1".
        lineage_attribute = "serotype"
        fauna_lineage = fauna_lineage.replace("denv", "")
    else:
        lineage_attribute = "lineage"

    if fauna_lineage is not None:
        return "--select %s:%s" % (lineage_attribute, fauna_lineage)
    else:
        return ""

def _get_fstem_argument(wildcards):
    """Return the filename stem for the current virus.
    """
    return "--fstem %s" % "_".join([wildcard
                                    for wildcard in [wildcards.virus, wildcards.lineage, wildcards.segment]])

def _get_resolve_method(wildcards):
    """Return a resolve_method argument for fauna sequence downloads if one has been
    defined for the given virus.
    """
    if "resolve_method" in config["viruses"][wildcards.virus]:
        return "--resolve_method %s" % config["viruses"][wildcards.virus]["resolve_method"]
    else:
        return ""

def _get_process_arguments(wildcards):
    """Return any custom arguments the user has defined in the configuration for the
    process step.
    """
    # First try to get lineage-specific arguments. Then try to get
    # virus-specific arguments.
    process_arguments = config["viruses"][wildcards.virus].get(wildcards.lineage, {}).get("process_arguments")

    if process_arguments is None:
        process_arguments = config["viruses"][wildcards.virus].get("process_arguments")

    if process_arguments is not None:
        # Clean up arguments to prevent accidental or intentional injections. This
        # works by identifying and removing any potentially dangerous punctuation
        # characters (e.g., ";" or "|").
        tokens = shlex.shlex(process_arguments, punctuation_chars=True, posix=True)
        process_arguments = " ".join([token for token in tokens
                                      if token not in tokens.punctuation_chars])

        return process_arguments
    else:
        return ""

def _get_prepare_inputs_by_virus_lineage(wildcards):
    """Determine which inputs should be built for the given virus/lineage especially
    in the case when a virus may have titers available.
    """
    inputs = {"sequences": "fauna/data/{wildcards.virus}_{wildcards.lineage}_{wildcards.segment}.fasta".format(wildcards=wildcards)}

    # Titers can be enabled at the virus or lineage level.
    if config["viruses"][wildcards.virus].get("has_titers", False) or config["viruses"][wildcards.virus].get(wildcards.lineage, {}).get("has_titers", False):
        inputs["titers"] = "fauna/data/{wildcards.virus}_{wildcards.lineage}_titers.tsv".format(wildcards=wildcards)

    return inputs

def _get_titers_argument_by_virus_lineage(wildcards, input):
    """Return a prepare argument for titers if the current virus/lineage has
    available titers.
    """
    if hasattr(input, "titers"):
        return "--titers %s" % os.path.join(SNAKEMAKE_DIR, input.titers)
    else:
        return ""

#
# Prepare outputs for local and remote storage.
#

def _rename_local_file_as_remote(local_file):
    """Returns the name of a file generated by this pipeline in the simpler format
    expected by auspice.

    For example, "zika_all_all_all_meta.json" becomes "zika_meta.json".
    """
    return os.path.split(local_file)[-1].replace("_all", "")

LOCAL_OUTPUTS = _get_json_outputs_by_virus(config)
FILENAMES = [_rename_local_file_as_remote(output) for output in LOCAL_OUTPUTS]
REMOTE_OUTPUTS = expand("remote/{filename}", filename=FILENAMES)
S3_BUCKET = config["s3_bucket"]

rule all:
    input: LOCAL_OUTPUTS

#
# Prepare outputs to push to an S3 bucket.
#

def _get_cloudfront_id(wildcards):
    """Return the CloudFront id corresponding to a name defined in the user
    configuration. If no id can be found, return None.
    """
    cloudfront_id = None

    # User has requested a CloudFront invalidation by name.
    if "cloudfront" in config:
        if "cloudfront_ids" in config:
            if config["cloudfront"] in config["cloudfront_ids"]:
                cloudfront_id = config["cloudfront_ids"][config["cloudfront"]]
            else:
                logger.error("The requested CloudFront name, '%s', does not have a corresponding id in the configuration." % config["cloudfront"])
        else:
            logger.error("No CloudFront name/id mappings are defined in the configuration.")

    return cloudfront_id

rule push:
    input: REMOTE_OUTPUTS
    params: cloudfront=_get_cloudfront_id
    run:
        # Prevent pushing directly to production buckets.
        production_buckets = ["nextstrain-data"]

        if S3_BUCKET in production_buckets:
            logger.error("Cannot push directly to a production S3 bucket.")
            return

        # Build a list of include expressions for each remote output. For an
        # output like "zika_meta.json", the include will look like `--include
        # zika_*.json`.
        includes = []
        for json in input:
            includes.append("--include \"%s\"" % os.path.split(json)[-1].replace("_meta.json", "_*.json"))

        # Push local outputs to an S3 bucket. Exclude all files by default and
        # sync only those matching the includes list.
        shell("""aws --profile nextstrain s3 sync `dirname {input[0]}` s3://{S3_BUCKET}/ --exclude "*" %s""" % " ".join(includes))

        # If a CloudFront name is given by the user and it matches a name in the
        # configuration, the corresponding CloudFront distribution id will be
        # used to create an invalidation request.
        if params.cloudfront is not None:
            # Always enable the CloudFront preview interface.
            shell("aws configure set preview.cloudfront true")

            # Create the invalidation request.
            shell("aws --profile nextstrain s3 cloudfront create-invalidation --distribution-id {params.cloudfront}")

rule prepare_builds_for_remote:
    input: LOCAL_OUTPUTS
    output: REMOTE_OUTPUTS
    run:
        # Each local output is a single "*_meta.json" file that corresponds to
        # one or more additional JSON files with the same prefix. For example,
        # the output "zika_meta.json" will also have an associated
        # "zika_tree.json" output. The following copy command(s) should copy and
        # rename all files corresponding to each local output.
        remote_dir = os.path.split(output[0])[0]
        for i in range(len(input)):
            # Local output (e.g., "augur/zika/auspice/zika_all_all_all_meta.json")
            local = input[i]

            # Remote output (e.g., "remote/zika_meta.json")
            remote = output[i]

            # Find all local outputs corresponding to the current file.
            local_files = glob.glob(local.replace("_meta.json", "_*.json"))

            # Rename local outputs to remote names and copy them.
            for local_file in local_files:
                renamed_local_file = _rename_local_file_as_remote(local_file)
                remote_file = os.path.join(remote_dir, renamed_local_file)
                shell("rsync -z {local_file} {remote_file}")

#
# Prepare and process viruses by lineage.
#

rule process_virus_lineage:
    input: "augur/{virus}/prepared/{virus}_{lineage}_{segment}_{resolution}.json"
    output: "augur/{virus}/auspice/{virus}_{lineage}_{segment}_{resolution}_meta.json"
    log: "log/process_{virus}_{lineage}_{segment}_{resolution}.log"
    params: process_arguments=_get_process_arguments
    benchmark: "benchmarks/process/{virus}_{lineage}_{segment}_{resolution}.txt"
    shell: "cd augur/{wildcards.virus} && python {wildcards.virus}.process.py -j {SNAKEMAKE_DIR}/{input} {params.process_arguments} &> {SNAKEMAKE_DIR}/{log}"

def _get_file_prefix(wildcards, output):
    """Return a file prefix for the given virus/lineage.
    """
    output_dir, output_file = os.path.split(output[0])
    return output_file.replace(".json", "")

rule prepare_virus_lineage:
    input: unpack(_get_prepare_inputs_by_virus_lineage)
    output: "augur/{virus}/prepared/{virus}_{lineage}_{segment}_{resolution}.json"
    log: "log/prepare_{virus}_{lineage}_{segment}_{resolution}.log"
    params:
        lineage=_get_lineage_argument_by_virus_lineage,
        viruses_per_month=_get_viruses_per_month,
        resolution=_get_resolution_argument_by_virus_lineage,
        segment=_get_segment_argument_by_virus_lineage,
        sampling=_get_sampling_argument_by_virus_lineage,
        titers=_get_titers_argument_by_virus_lineage,
        prefix=_get_file_prefix
    benchmark: "benchmarks/prepare/{virus}_{lineage}_{segment}_{resolution}.txt"
    shell: """cd augur/{wildcards.virus} && python {wildcards.virus}.prepare.py {params.lineage} \
              {params.resolution} {params.segment} {params.sampling} \
              -v {params.viruses_per_month} {params.titers} \
              --sequences {SNAKEMAKE_DIR}/{input.sequences} \
              --file_prefix {params.prefix} &> {SNAKEMAKE_DIR}/{log}"""

#
# Download data with fauna
#

rule download_virus_lineage_titers:
    output: "fauna/data/{virus}_{lineage}_titers.tsv"
    log: "log/fauna_titers_{virus}_{lineage}.log"
    benchmark: "benchmarks/fauna_{virus}_{lineage}_titers.txt"
    shell: "cd fauna && python tdb/download.py -db tdb -v {wildcards.virus} --subtype {wildcards.lineage} --select assay_type:hi --fstem {wildcards.virus}_{wildcards.lineage} &> {SNAKEMAKE_DIR}/{log}"

rule download_virus_lineage_sequences:
    output: "fauna/data/{virus}_{lineage}_{segment}.fasta"
    log: "log/fauna_sequences_{virus}_{lineage}_{segment}.log"
    params:
        virus=_get_fauna_virus,
        locus=_get_locus_argument,
        fauna_lineage=_get_fauna_lineage_argument,
        fstem=_get_fstem_argument,
        resolve_method=_get_resolve_method
    benchmark: "benchmarks/fauna_{virus}_{lineage}_{segment}_fasta.txt"
    shell: "cd fauna && python vdb/{params.virus}_download.py -db vdb -v {params.virus} {params.locus} {params.fauna_lineage} {params.fstem} {params.resolve_method} &> {SNAKEMAKE_DIR}/{log}"

#
# Clean up output files for quick rebuild without redownload
#

rule clean:
    params: viruses=list(_get_virus_builds(config).keys())
    shell: """for virus in {params.viruses}
do
    rm -f augur/$virus/prepared/$virus*;
    rm -f augur/$virus/processed/$virus*;
    rm -f augur/$virus/auspice/$virus*;
    rm -f remote/$virus*;
done"""
