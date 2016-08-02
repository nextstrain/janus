## Introduction

The nextstrain project is an attempt to make flexible informatic pipelines and visualization tools to track ongoing pathogen evolution as sequence data emerges. The nextstrain project derives from [nextflu](https://github.com/blab/nextflu), which was specific to influenza evolution.

nextstrain is comprised of three components:

* [db](https://github.com/blab/nextstrain-db): database and IO scripts for sequence and serological data
* [augur](https://github.com/blab/nextstrain-augur): informatic pipelines to conduct inferences from raw data
* [auspice](https://github.com/blab/nextstrain-auspice): web app to visualize resulting inferences
* [deploy](https://github.com/blab/nextstrain-deploy): build and deploy scripts

## Development

The current repo is very much a work-in-progress. We recommend that you use [nextflu](https://github.com/blab/nextflu) instead for current applications. At some point, this repo will takeover from the nextflu repo.

## Deploy

This repo is intended to ease deployment of nextstrain instances. It currently submodules [nextstrain-db](https://github.com/blab/nextstrain-db), [nextstrain-augur](https://github.com/blab/nextstrain-augur) and [nextstrain-auspice](https://github.com/blab/nextstrain-auspice). Docker images and build scripts are provided.
