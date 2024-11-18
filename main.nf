#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VCS Recombination Pipeline : Workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process CHECK_DIRS {
    
    input:
    val(obsid)
    val(download_dir)
    val(vcs_dir)

    output:
    tuple env(offset), env(duration)

    script:
    """
    log_err() { echo "ERROR: \$@" 1>&2; exit 1; }
    count() { echo "\$#"; }
    first_arg() { echo "\$1" | xargs -n1 basename; }
    last_arg() { echo "\${@: -1}" | xargs -n1 basename; }

    # Check that the specified directories exist
    [[ -d '${vcs_dir}' ]] || log_err "Directory does not exist: ${vcs_dir}"
    [[ -d '${download_dir}' ]] || log_err "Directory does not exist: ${download_dir}"

    # Check that the obs ID directory exists, if not make it
    obsid_dir='${vcs_dir}/${obsid}'
    if [[ ! -d "\$obsid_dir" ]]; then
        mkdir "\$obsid_dir" || log_err "Could not create directory: \$obsid_dir"
    fi

    # Check that the metafits file exists
    metafits='${obsid}_metafits_ppds.fits'
    if [[ ! -f "\$obsid_dir/\$metafits" ]]; then
        if [[ -f "${download_dir}/\$metafits" ]]; then
            cp "${download_dir}/\$metafits" "\${obsid_dir}" \\
                || log_err "Could not copy metafits file into directory: \${obsid_dir}"
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
    dest_dir="\${obsid_dir}/combined"
    if [[ ! -d "\$dest_dir" ]]; then
        mkdir -p "\$dest_dir" || log_err "Could not create directory: \$dest_dir"
    elif [[ \$(shopt -s nullglob; count "\$dest_dir"/*.dat) -gt 0 ]]; then
        log_err "Combined (.dat) files found in directory: \$dest_dir"
    fi
    """
}

process GENERATE_RECOMBINE_JOBS {
    label 'python'

    input:
    tuple val(obsid), val(offset), val(duration), val(increment)

    output:
    path("${obsid}_recombine_jobs.txt")

    script:
    """
    generate_recombine_jobs.py \\
        --obsid ${obsid} \\
        --offset ${offset} \\
        --duration ${duration} \\
        --increment ${increment}
    """
}

process RECOMBINE {
    
    errorStrategy { task.attempt > 1 ? 'finish' : 'retry' }
    maxRetries 1

    input:
    tuple val(begin), val(increment)
    val(obsid)
    val(download_dir)
    val(vcs_dir)

    script:
    """
    srun -N \$SLURM_JOB_NUM_NODES -n \$SLURM_NTASKS -c \$SLURM_CPUS_PER_TASK -m block:block:block recombine_wrapper \\
        ${obsid} \\
        ${begin} \\
        ${vcs_dir}/${obsid}/${obsid}_metafits_ppds.fits \\
        ${download_dir} \\
        ${vcs_dir}/${obsid}/combined
    """
}

workflow {

    // Check that a cluster config was loaded
    if (params.cluster == null) {
        System.err.println("ERROR: Cluster not recognised")
    }

    // Check that the required parameters have been provided
    if (params.download_dir == null) {
        System.err.println("ERROR: Parameter '--download_dir' not specified")
    }
    if (params.obsid == null) {
        System.err.println("ERROR: Parameter '--obsid' not specified")
    }

    // Run the pipeline
    if (params.cluster != null && params.download_dir != null && params.obsid != null) {
            CHECK_DIRS(params.obsid, params.download_dir, params.vcs_dir)

            if (params.offset != null && params.duration != null) {
                Channel
                    .of(
                        [
                            Integer.valueOf(params.obsid),
                            Integer.valueOf(params.offset),
                            Integer.valueOf(params.duration),
                            Integer.valueOf(params.rc_ntasks)
                        ]
                    )
                    .set { data_info }
            } else {
                CHECK_DIRS.out
                    .map {
                        [
                            Integer.valueOf(params.obsid),
                            Integer.valueOf(it[0]),
                            Integer.valueOf(it[1]),
                            Integer.valueOf(params.rc_ntasks)
                        ]
                    }
                    .set { data_info }
            }

            GENERATE_RECOMBINE_JOBS(data_info)

            GENERATE_RECOMBINE_JOBS.out
                .splitCsv()
                .map { job -> [Integer.valueOf(job[0]), Integer.valueOf(job[1])] }
                .set { recombine_jobs }
            
            RECOMBINE(
                recombine_jobs,
                params.obsid,
                params.download_dir,
                params.vcs_dir
            )
        }
}
