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
# 18-run scenario suite on edge model version L3 (decision D1, 2026-08-29). The LAUNCHER runs on a
# compute node (Mike 2026-08-28: launch prep never on the login node); each start_run submits its own
# solve via nested sbatch (submit_short.sh keeps END,FAIL mail for the real MAgPIE solves).
cd /p/projects/magpie/users/crawford/dev_fragmentation/libraries/magpie || exit 1
echo "node $(hostname) start $(date)  HEAD $(git rev-parse --short HEAD)"
Rscript scripts/start/projects/scenario_suite_emissions_fragmentation.R
echo "launcher done $(date)"
