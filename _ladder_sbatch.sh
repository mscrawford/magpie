#!/bin/bash
#SBATCH --job-name=ladder-launch
#SBATCH --qos=short
#SBATCH --partition=standard
#SBATCH --account=magpie
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=_ladder_launch_%j.log
# Edge model-version ladder: run the LAUNCHER on a compute node (Mike 2026-08-28: launch prep never on
# the login node). Each start_run submits its own solve job from here (nested sbatch).
cd /p/projects/magpie/users/crawford/dev_fragmentation/libraries/magpie || exit 1
echo "node $(hostname) start $(date)"
LADDER_RUNGS=L2,L3,OFF LADDER_SCEN=SSP2base Rscript scripts/start/projects/edge_version_ladder.R
LADDER_RUNGS=L0b,L1,L2,L3,OFF LADDER_SCEN=SSP1mitig Rscript scripts/start/projects/edge_version_ladder.R
echo "launcher done $(date)"
