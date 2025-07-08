#!/bin/bash

export FREESURFER_HOME=/Applications/freesurfer/8.0.0
export SUBJECTS_DIR=$FREESURFER_HOME/subjects
source $FREESURFER_HOME/SetUpFreeSurfer.sh

for hemi in lh rh; do
  for vol in /Users/nicholasharp/Desktop/spintests_v2/ns_fi_FWE_height/*.nii; do
    name=$(basename "$vol" .nii)
    mri_vol2surf \
      --mov "$vol" \
      --hemi $hemi \
      --o fs5_mids_height/${hemi}.${name}_fs5.mgh \
      --surfreg $SUBJECTS_DIR/fsaverage5 \
      --regheader fsaverage5 \
      --projfrac 0.5 \
      --interp nearest \
      --mni152reg 
  done
done
