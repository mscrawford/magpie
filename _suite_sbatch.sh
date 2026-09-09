#!/bin/bash
#SBATCH --job-name=suite-launch
#SBATCH --qos=short
#SBATCH --partition=standard
#SBATCH --account=magpie
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --mail-type=FAIL
#SBATCH --output=_suite_launch_%j.log
# 17-run scenario suite, DESIGN B (Mike 2026-09-09; launcher 5a7bd2ca3, third-party validated). The LAUNCHER runs on a
# compute node (Mike 2026-08-28: launch prep never on the login node); each start_run submits its own
# solve via nested sbatch (submit_short.sh keeps END,FAIL mail for the real MAgPIE solves).
cd /p/projects/magpie/users/crawford/dev_fragmentation/libraries/magpie || exit 1
echo "node $(hostname) start $(date)  HEAD $(git rev-parse --short HEAD)"
Rscript scripts/start/projects/scenario_suite_emissions_fragmentation.R
echo "launcher done $(date)"
