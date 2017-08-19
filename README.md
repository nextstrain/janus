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

Install Python environment.

```bash
./install.sh
```

### Configuration

Setup AWS credentials before the first Janus run.

```bash
mkdir ~/.aws
chmod 700 ~/.aws
touch ~/.aws/credentials
chmod 600 ~/.aws/credentials
```

Add a `nextstrain` profile to the credentials file.

```ini
[nextstrain]
aws_access_key_id =
aws_secret_access_key =
```

Set database variables in the environment before each Janus run.

```bash
export RETHINK_HOST=
export RETHINK_AUTH_KEY=
export NCBI_EMAIL=
```

### Usage

The fike `config.json` stores information on which viruses, lineages, and resolutions to build. Builds can be specified with `--config builds="flu,zika"`.

Perform a dry-run of the builds by printing the rules that will be executed
for the configuration with `--dryrun`.

```bash
./janus --dryrun --config builds="flu,zika"
```

If everything looks good, run builds on the cluster. For example, the following
command runs no more than 4 builds at a time. All arguments to `janus` are
passed through to `snakemake`. If `-j` is not specified, it defaults to `-j 1` with a single job run simultaneously.

```bash
./janus -j 4 --config builds="flu,zika"
```

By default, all augur builds defined in `config["builds"]` will be built locally
and not synced to S3. Use the `push` rule to build one or more specific viruses
and push them to S3.

```bash
./janus -j 4 push
```

The following command builds seasonal flu, Zika, and Ebola files and pushes the
corresponding auspice output to the development data bucket on S3. A
`cloudfront` argument can be added to create an invalidation request for the
corresponding development CloudFront account (e.g., `cloudfront=dev`).

```bash
./janus -j 4 push --config builds="flu,zika" s3_bucket=nextstrain-dev-data
```

Use the `clean` rule to delete prepared, processed, and auspice files from one
or more builds.

```bash
./janus -j 1 clean --config builds="flu,zika"
```

## License and copyright

Copyright 2016-2017 Trevor Bedford.

Source code to nextstrain is made available under the terms of the [GNU Affero General Public License](LICENSE.txt) (AGPL). nextstrain is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.
