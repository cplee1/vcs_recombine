#!/usr/bin/env python3

import argparse
import csv


def main() -> None:
    parser = argparse.ArgumentParser(
        usage="%(prog)s [options]",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Generate job specifications for recombining VCS data.",
        add_help=False,
    )
    parser.add_argument(
        "-h",
        "--help",
        action="help",
        help="Show this help information and exit.",
    )
    parser.add_argument(
        "-o",
        "--obsid",
        type=int,
        required=True,
        help="The MWA observation ID.",
    )
    parser.add_argument(
        "--offset",
        type=int,
        required=True,
        help="The start time offset from the obs ID.",
    )
    parser.add_argument(
        "-d",
        "--duration",
        type=int,
        required=True,
        help="The total time span of data to process.",
    )
    parser.add_argument(
        "-i",
        "--increment",
        type=int,
        default=32,
        help="The maximum size of each job.",
    )
    args = parser.parse_args()

    begin = args.obsid + args.offset
    end = args.obsid + args.offset + args.duration
    init_increment = args.increment

    with open(f"{args.obsid}_recombine_jobs.txt", "w") as outfile:
        writer = csv.writer(outfile, delimiter=",")
        for time_step in range(begin, end, init_increment):
            if time_step + init_increment > end:
                increment = end - time_step + 1
            else:
                increment = init_increment
            writer.writerow([time_step, increment])


if __name__ == "__main__":
    main()