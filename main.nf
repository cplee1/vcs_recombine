#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VCS Recombination Pipeline : Workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process CHECK_DIRS {
    
    input:
    val(obsid)
    val(obsid_dir)
    val(download_dir)

    output:
    tuple env(offset), env(duration)

    script:
    """
    log_err() { echo "ERROR: \$@" 1>&2; exit 1; }
    count() { echo "\$#"; }
    first_arg() { echo "\$1" | xargs -n1 basename; }
    last_arg() { echo "\${@: -1}" | xargs -n1 basename; }

    # Check that the specified directories exist
    [[ -d ${obsid_dir} ]] || log_err "Directory does not exist: ${obsid_dir}"
    [[ -d ${download_dir} ]] || log_err "Directory does not exist: ${download_dir}"

    # Check that the metafits file exists
    metafits="${obsid}_metafits_ppds.fits"
    if [[ ! -f "${obsid_dir}/\$metafits" ]]; then
        if [[ -f "${download_dir}/\$metafits" ]]; then
            cp "${download_dir}/\$metafits" "${obsid_dir}" \\
                || log_err "Could not copy metafits file into directory: ${obsid_dir}"
        else
            log_err "Could not locate file: \$metafits"
        fi
    fi

    # Check that the raw data exists
    [[ \$(shopt -s nullglob; count '${download_dir}'/*.dat) -gt 0 ]] \\
        || log_err "No raw (.dat) files found in directory: ${download_dir}"

    # Get the start time and duration
    IFS='_' read -r obsid0 gpstime0 boxname0 stream0 <<< "\$(first_arg '${download_dir}'/*.dat)"
    IFS='_' read -r obsid1 gpstime1 boxname1 stream1 <<< "\$(last_arg '${download_dir}'/*.dat)"
    offset=\$((gpstime0-obsid0))
    duration=\$((gpstime1-gpstime0+1))

    # Make a directory for the combined data
    outdir='${obsid_dir}/combined'
    if [[ ! -d "\$outdir" ]]; then
        mkdir -p "\$outdir" || log_err "Could not create directory: \$outdir"
    elif [[ \$(shopt -s nullglob; count "\$outdir"/*.dat) -gt 0 ]]; then
        log_err "Combined (.dat) files found in directory: \$outdir"
    fi
    """
}

process GENERATE_RECOMBINE_JOBS {

    beforeScript "module use ${params.module_dir}; module load python/3.8.2"
    shell '/usr/bin/env', 'python'

    input:
    tuple val(obsid), val(offset), val(duration), val(increment)

    output:
    path("${obsid}_recombine_jobs.txt")

    script:
    """
    import csv

    begin = ${obsid + offset}
    end = ${obsid + offset + duration}
    init_increment = ${increment}

    with open(f"${obsid}_recombine_jobs.txt", "w") as outfile:
        writer = csv.writer(outfile, delimiter=",")
        for time_step in range(begin, end, init_increment):
            if time_step + init_increment > end:
                increment = end - time_step + 1
            else:
                increment = init_increment
            writer.writerow([time_step, increment])
    """
}

process RECOMBINE {

    label 'cpu'
    memory { "${increment * 5} GB" }
    time { "${500 * increment * task.attempt + 900} s" }
    errorStrategy { task.attempt > 1 ? 'finish' : 'retry' }
    maxRetries 1
    maxForks 30
    clusterOptions { "--nodes=1 --ntasks-per-node=${increment}" }
    beforeScript "module use ${params.module_dir}; module load vcstools/master; module load mwa-voltage/master"

    input:
    val(obsid)
    val(obsid_dir)
    val(download_dir)
    tuple val(begin), val(increment)

    script:
    """
    srun --export=all recombine.py \\
    -o ${obsid} \\
    -s ${begin} \\
    -d ${increment} \\
    -w ${download_dir} \\
    -p ${obsid_dir}

    checks.py \\
    -m recombine \\
    -o ${obsid} \\
    -w ${obsid_dir}/combined \\
    -b ${begin} \\
    -i ${increment}
    """
}

workflow {

    if (params.download_dir == null) {
        System.err.println("ERROR: 'download_dir' not defined")
    }
    if (params.obsid == null) {
        System.err.println("ERROR: 'obsid' not defined")
    }
    if (params.download_dir != null && params.obsid != null) {
            // If all inputs are defined, run the pipeline

            CHECK_DIRS(params.obsid, "${params.vcs_dir}/${params.obsid}", params.download_dir)

            if (params.offset != null && params.duration != null) {
                CHECK_DIRS.out
                    .map { [Integer.valueOf(params.obsid), Integer.valueOf(params.offset), Integer.valueOf(params.duration), Integer.valueOf(params.increment)] }
                    .set { data_info }
            } else {
                CHECK_DIRS.out
                    .map { [Integer.valueOf(params.obsid), Integer.valueOf(it[0]), Integer.valueOf(it[1]), Integer.valueOf(params.increment)] }
                    .set { data_info }
            }

            GENERATE_RECOMBINE_JOBS(data_info)

            recombine_jobs = GENERATE_RECOMBINE_JOBS.out
                .splitCsv()
                .map { job -> [Integer.valueOf(job[0]), Integer.valueOf(job[1])] }
            
            RECOMBINE(
                params.obsid,
                "${params.vcs_dir}/${params.obsid}",
                params.download_dir,
                recombine_jobs
            )
        }
}
