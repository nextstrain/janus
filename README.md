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

## License and copyright

Copyright 2016 Trevor Bedford.

Source code to nextstrain is made available under the terms of the [GNU Affero General Public License](LICENSE.txt) (AGPL). nextstrain is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.
