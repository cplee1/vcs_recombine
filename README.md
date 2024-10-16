# VCS Recombination Pipeline
A simple pipeline to recombine legacy VCS data.

## Using the Pipeline

> [!NOTE]
> If you are new to Nextflow, please refer to [this page](https://www.nextflow.io/docs/latest/install.html#installation).

Simply run:

```bash
nextflow run cplee1/vcs_recombine \
    --download_dir <PATH> \
    --obsid <OBSID> \
    [--offset <OFFSET>] \
    [--duration <DURATION>] \
    [--vcs_dir <PATH>]
```

The required options are as follows:

  - `--download_dir` : The path to the directory containing the raw `.dat` files
  - `--obsid` : The observation ID

By default, the pipeline will attempt to recombine all data in the download directory.
If you want to manually specify the data to recombine, you can optionally specify the following:

  - `--offset` : The offset (in seconds) between the observation ID and the first second of data to recombine
  - `--duration` : The duration (in seconds) of the downloaded data to recombine

The combined data will be placed in the directory `$vcs_dir/$obsid/combined`. 
The VCS directory can be specifed with:

  - `--vcs_dir` : The path to the parent directory containing the obs ID directory. Default: `/scratch/mwavcs/$USER/vcs_downloads`

