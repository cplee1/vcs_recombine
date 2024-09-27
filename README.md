# VCS Recombination Pipeline
A simple pipeline to recombine legacy VCS data.

## Nextflow Setup
To download the latest version of Nextflow, run:

    curl -s https://get.nextflow.io | bash

This will download the Nextflow binary into your current directory. Then make it executable with:

    chmod +x nextflow

Then move Nextflow into an executable path. Nextflow requires Java to run. On Garrawarla, this can be loaded with:

    module load java/17

## Using the Pipeline
Simply run:

```bash
nextflow run cplee1/vcs_recombine \
    --download_dir <PATH> \
    --obsid <OBSID> \
    --offset <OFFSET> \
    --duration <DURATION> \
    --vcs_dir <PATH>
```

The options are as follows:

  - `--download_dir` : The path to the directory containing the raw `.dat` files
  - `--obsid` : The observation ID
  - `--offset` : The offset (in seconds) between the observation ID and the first second of data
  - `--duration` : The duration (in seconds) of the downloaded data
  - `--vcs_dir` : The path to the base directory of VCS downloads. Default: `/scratch/mwavcs/$USER/vcs_downloads`

The pipeline will read the raw files in the download directory, then write the combined files to `$vcs_dir/$obsid/combined`. One job will be submitted per 32 seconds of data, with one node allocated.
