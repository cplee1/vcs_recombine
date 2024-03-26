#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VCS Recombination Pipeline : Workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process CHECK_DIRS {
    
    input:
    val(obsid_dir)
    val(download_dir)

    output:
    tuple val(obsid_dir), val(download_dir)

    script:
    """
    if [[ ! -d ${obsid_dir} ]]; then
        echo "ERROR :: The observation directory does not exist: ${obsid_dir}"
        exit 1
    fi

    if [[ ! -d ${download_dir} ]]; then
        echo "ERROR :: The download directory does not exist ${download_dir}"
        exit 1
    fi
    
    if [[ ! -e \$(find ${download_dir} -type f -name *.dat | head -n1) ]]; then
        echo "ERROR :: No raw (.dat) files found. Exiting."
        exit 1
    fi

    if [[ ! -d ${obsid_dir}/combined ]]; then
        mkdir -p ${obsid_dir}/combined
    elif [[ -e \$(find ${obsid_dir}/combined -type f -name *.dat | head -n1) ]]; then
        echo "ERROR :: Combined (.dat) files already present. Exiting."
        exit 1
    fi
    """
}

process GENERATE_RECOMBINE_JOBS {

    beforeScript "module use ${params.module_dir}; module load python/3.8.2"
    shell '/usr/bin/env', 'python'

    input:
    val(obsid)
    val(duration)
    val(offset)
    val(increment)

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
    maxForks 15
    clusterOptions { "--nodes=1 --ntasks-per-node=${increment}" }
    beforeScript "module use ${params.module_dir}; module load vcstools/master; module load mwa-voltage/master"

    input:
    tuple val(obsid_dir), val(download_dir)
    tuple val(begin), val(increment)
    val(obsid)

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
        System.err.println("ERROR :: 'download_dir' not defined")
    }
    if (params.offset == null) {
        System.err.println("ERROR :: 'offset' not defined")
    }
    if (params.duration == null) {
        System.err.println("ERROR :: 'duration' not defined")
    }
    if (params.obsid == null) {
        System.err.println("ERROR :: 'obsid' not defined")
    }
    if (params.download_dir != null \
        && params.offset != null \
        && params.duration != null \
        && params.obsid != null) {
            // If all inputs are defined, run the pipeline

            CHECK_DIRS("${params.vcs_dir}/${params.obsid}", params.download_dir)

            GENERATE_RECOMBINE_JOBS(params.obsid, params.duration, params.offset, params.increment)

            recombine_jobs = GENERATE_RECOMBINE_JOBS.out
                .splitCsv()
                .map { job -> [Integer.valueOf(job[0]), Integer.valueOf(job[1])] }
            
            RECOMBINE(CHECK_DIRS.out, recombine_jobs, params.obsid)
        }
}
