#!/bin/bash
# Re-report MAgPIE runs with the MAIN renv's magpie4 as SLURM jobs (one per run), never job-end reports.
# Own sbatch wrapper (NOT output.R's submit="SLURM standby", whose slurmOutput.yml modes hardcode
# --mail-type=END,FAIL): mail on FAIL only (Mike 2026-08-28: no ExitCode-0 mails from R-development jobs).
# Usage (from the magpie root, on the login node - sbatch only, no R runs here):
#   bash _rereport_submit.sh output/<run1> output/<run2> ...
#   OUTPUT=rds_report,extra/disaggregation bash _rereport_submit.sh output/<run> ...   (report + cell.land_0.5.mz)
# Each existing report.rds is kept as report.rds.bak-<timestamp> first (reversible).
OUTPUT="${OUTPUT:-rds_report}"
cd /p/projects/magpie/users/crawford/dev_fragmentation/libraries/magpie || exit 1
mkdir -p logs
for d in "$@"; do
  [ -f "$d/fulldata.gdx" ] || { echo "skip (no gdx): $d"; continue; }
  [ -f "$d/report.rds" ] && cp -p "$d/report.rds" "$d/report.rds.bak-$(date +%Y%m%d-%H%M)"
  sbatch --job-name=rereport --qos=standby --account=magpie --cpus-per-task=3 --mem-per-cpu=5G \
         --time=03:20:00 --mail-type=FAIL --output=logs/rereport-%j.out --error=logs/rereport-%j.err \
         --wrap="SLURM_JOB_ID=1 Rscript output.R outputdir=$d output=$OUTPUT submit=direct" \
    | sed "s|^|$(basename $d): |"
done
