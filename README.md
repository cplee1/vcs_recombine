# VCS Recombination Pipeline
A simple pipeline to recombine legacy VCS data, based on the vcs_download.nf pipeline from mwa_search.

## Nextflow Setup
I recommend using the latest binary for Nextflow. To do this, navigate to a directory in your `$PATH` (or add a directory to your `$PATH`) and run the following:

    wget -qO- https://get.nextflow.io | bash

This will download the Nextflow binary to your current directory. Then make it executable with:

    chmod +x nextflow

Nextflow requires Java to run. On Garrawarla, this can be loaded with:

    module load java/17

## Pipeline Setup
Simply clone the repository and make the pipeline executable with:

    chmod +x vcs_recombine.nf

Optionally, add the pipeline script to your `$PATH`. You can now execute the pipeline as you would any other script.

## Using the Pipeline
The basic syntax is as follows. Inputs in square brackets are optional.

    vcs_recombine.nf --download_dir </path/to/raw/data> --obsid <obsid> --offset <offset> --duration <duration> [--vcs_dir </path/to/vcs>]

The options are as follows:

  - `--download_dir` : The path to the directory containing the raw `.dat` files
  - `--obsid` : The observation ID
  - `--offset` : The offset (in seconds) from the beginning of the observation
  - `--duration` : The duration (in seconds) of the downloaded data
  - `--vcs_dir` : The path to the base directory of VCS downloads. Default: `/scratch/mwavcs/$USER/vcs_downloads`

The pipeline will read the raw files in the download directory, then write the combined files to `$vcs_dir/$obsid/combined`. One job will be submitted per 32 seconds of data, with one node allocated.
