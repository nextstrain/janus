## Introduction

The nextstrain project is an attempt to make flexible informatic pipelines and visualization tools to track ongoing pathogen evolution as sequence data emerges. The nextstrain project derives from [nextflu](https://github.com/blab/nextflu), which was specific to influenza evolution.

nextstrain is comprised of four components:

* [fauna](https://github.com/nextstrain/fauna): database and IO scripts for sequence and serological data
* [augur](https://github.com/nextstrain/augur): informatic pipelines to conduct inferences from raw data
* [auspice](https://github.com/nextstrain/auspice): web app to visualize resulting inferences
* [janus](https://github.com/nextstrain/janus): build and deploy scripts

## Janus

*Definition: Roman god of beginnings and passages.*

This repo is intended to ease deployment of nextstrain instances. It's goal is to provide deploy scripts for augur builds.

## Docker commands

Build base Docker image

    docker build -t nextstrain/base:latest -f Dockerfile.base .

Push base image to hub

    docker push nextstrain/base:latest

Build janus Docker image

    docker build -t nextstrain/janus:latest .

Push janus image to hub

    docker push nextstrain/janus:latest

Run a shell from within the container

    docker run -t -i nextstrain/janus /bin/bash

Run a shell from within the container, including environment variables

    docker run -t -i --env-file environment_janus.env nextstrain/janus /bin/bash

## Testing

Enter shell

    docker run -t -i --env-file environment_janus.env nextstrain/janus /bin/bash

Build Zika

    python build.py

## Building with Snakemake

### Installation

Check out the code and branch.

```bash
git clone --recursive https://github.com/nextstrain/janus.git
cd janus
git submodule update --init --recursive
```

Or make sure to update to latest version.

```bash
git pull origin master
git submodule update
```

Install Python environment.

```bash
./install.sh
```

### Environment configuration

Define database environment variables `RETHINK_HOST`, `RETHINK_AUTH_KEY`, and
`NCBI_EMAIL` before trying to download data with fauna.

Define AWS credentials in the `AWS_SECRET_ACCESS_KEY` and `AWS_ACCESS_KEY_ID`
environment variables before trying to push auspice results to S3.

### Build configuration

Janus uses a JSON configuration file to define a list of one or more augur
builds to run (e.g., `zika`, `ebola`, or `flu_h3n2_ha_3y`). The configuration
file must provide a `builds` attribute with a corresponding list of one or more
build definitions. The following is an example empty configuration.

```json
{
    "builds": [
    ]
}
```

Builds are defined as dictionaries with two or more attributes. Each build
requires a `stem` that specifies the names of the augur output files and a
`virus` that corresponds to a virus supported by both fauna and augur. The
`virus` attribute specifically enables running the appropriate augur scripts
(e.g., `builds/{virus}/{virus}.prepare.py`). For example, the following
configuration defines a build instance for Zika that runs augur with default
parameters.

```json
{
    "builds": [
        {
            "stem": "zika",
            "virus": "zika"
        }
    ]
}
```

Builds can be defined as individual build instances, as shown above, or as build
templates that Janus expands to one or more individual build instances. Build
templates define variables with Python named string formatting in the `stem` and
matching attributes in the build definition. Variable attributes provide lists
of values to substitute in the `stem` and other optional non-list
attributes. The following example defines one build template with a variable
named `virus` and a list of two viruses to create individual build instances
for.

```json
{
    "builds": [
        {
            "stem": "{virus}",
            "virus": ["zika", "ebola"]
        }
    ]
}
```

Variables can be expanded into other non-list attributes of the build template
to customize parameters for augur’s prepare and process commands. For example,
the following build template uses the `virus` variable to specify which
sequences should be included when running the augur prepare command.

```json
{
    "builds": [
        {
            "stem": "{virus}",
            "virus": ["zika", "ebola"],
            "prepare": "--sequences ../fauna/{virus}.fasta"
        }
    ]
}
```

When multiple variables are defined in the `stem`, one build instance is created
for each combination of variable values. For example, the following build
template uses `lineage` and `resolution` variables to create all 12 possible
combinations of lineages and resolutions for seasonal flu.

```json
{
    "builds": [
        {
            "stem": "flu_{lineage}_ha_{resolution}",
            "virus": "flu",
            "lineage": ["h3n2", "h1n1pdm", "vic", "yam"],
            "resolution": ["3y", "6y", "12y"],
            "segments": "ha"
            "prepare": "--sequences ../fauna/{lineage}.fasta"
        }
    ]
}
```

As shown above, specific arguments can be passed directly to the augur prepare
command with the `prepare` attribute. Similarly, specific arguments can be
passed to the process command with a `process` attribute as shown below.

```json
{
    "builds": [
        {
            "stem": "zika",
            "virus": "zika",
            "process": "--no_raxml"
        }
    ]
}
```

Users can define any additional attributes they need to parameterize their
builds. For example, if a pathogen’s data is organized by serotype rather than
lineage, the maintainer for that pathogen can include a `serotype` variable in
the `stem`, assign a corresponding list of values to a `serotype` attribute in
the build definition, and provide the necessary `prepare` and `process`
arguments to run the build(s) correctly. The following configuration shows an
example of this approach with dengue virus.

```json
{
    "builds": [
        {
            "stem": "dengue_{serotype}",
            "virus": "dengue",
            "serotype": ["denv1", "denv2", "denv3", "denv4"],
            "prepare": "--serotype {serotype}"
        }
    ]
}
```

The complete set of attributes expected by Janus is listed below.

Required attributes:

  * `stem`: Name or name template for the build, used as the file prefix for augur outputs
  * `virus`: Name of a virus supported by fauna and augur

Optional attributes for augur prepare:

  * `lineage`: String or list of strings defining viral lineages to pass to the prepare script as `--lineages {lineage}`
  * `segments`: String or list of strings defining viral segments to pass to the prepare script as `--segments {segments}`
  * `resolution`: String or list of strings defining viral resolutions to pass to the prepare script as `--resolution {resolution}`
  * `prepare`: String of parameters to pass to the virus’s augur prepare command

Optional attributes for augur process:

  * `process`: String of parameters to pass to the virus’s augur process command

Other optional attributes:

  * `description`: String describing the build(s) represented by the build definition (e.g., “Flu builds for nextstrain.org”)

### Usage

Download all data (sequences, titers, etc.) for the viruses listed in the
`config.json` file using fauna.

```bash
./janus download
```

Dry run all builds defined in the `config.json` file, printing all rules that
would be run without running them. Note that all `janus` arguments except `-l`
are passed directly to the [snakemake
command](http://snakemake.readthedocs.io/en/stable/executable.html).

```bash
./janus -n
```

Run all builds on the cluster with no more than 4 cluster jobs at a time (note:
the `-j` argument is required).

```bash
./janus -j 4
```

Run all builds locally with no more than 4 jobs at a time.

```bash
./janus -l -j 4
```

Run only H3N2 and Zika builds on the cluster. The `filters` configuration
parameter supports a comma-delimited list of patterns to match in the complete
list of build stems defined in the configuration file. Standard UNIX wildcards
are supported through the [fnmatch Python
module](https://docs.python.org/2/library/fnmatch.html).

```bash
./janus -j 4 --config filters="flu_h3n2*,zika"
```

Filters also apply to all other rules including fauna downloads and the `clean`
rule described later. The following command will only download H3N2 data from
fauna.

```bash
./janus download -j 4 --config filters="flu_h3n2*"
```

Run all builds defined in a custom configuration file.

```bash
./janus -j 4 --configfile experimental_builds.json
```

Remove all augur outputs for all builds.

```bash
./janus clean -j 1
```

Alternately, force all existing augur outputs to be rebuilt.

```bash
./janus -j 4 --forceall
```

### Cluster configuration

The `janus` script is a wrapper for Snakemake that submits jobs to a SLURM
cluster using the [DRMAA Python
bindings](http://drmaa-python.readthedocs.io/en/latest/). Job requirements
(e.g., number of CPUs, memory, etc.) are defined in the `cluster.json` file as
described in [the Snakemake
documentation](http://snakemake.readthedocs.io/en/stable/snakefiles/configuration.html#cluster-configuration).

To run builds on [any other supported
cluster](http://snakemake.readthedocs.io/en/stable/tutorial/additional_features.html#cluster-execution),
load the Janus Python 3 environment and run Snakemake directly. For example, the
following command will run all builds on a Grid Engine-style cluster.

```bash
source activate janus_python3
snakemake -j 4 --cluster "qsub"
```

## License and copyright

Copyright 2016-2017 Trevor Bedford.

Source code to nextstrain is made available under the terms of the [GNU Affero General Public License](LICENSE.txt) (AGPL). nextstrain is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.
