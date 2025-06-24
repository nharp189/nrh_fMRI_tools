#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jun 20 13:25:03 2025

@author: nick
"""
import pandas as pd
import os
import shutil
import re

# === CONFIGURATION ===
source_dir = "/Volumes/Penguin/PDC3_Halfpiped"
destination_dir = "/Volumes/Penguin/PDC3_Bidsify"

# Read in excel sheet
df = pd.read_excel('/Volumes/G-DRIVE_Thunderbolt_3/For Ranjita/Docs/PDC3_sessions_data_nrh.xlsx', engine='openpyxl', skiprows = 1)

# Subset to only include 
df = df[df['SubID'].astype(str).str.contains('28', na=False)]

# Set up the mapping/dictionary for subjects and scans
scan_to_participant = dict(zip(df['SubID'], df['TB PRE']))

def parse_run_and_task(path):
    """
    Extract task and run number from folder path like /func/roc/run1/
    """
    parts = path.lower().split(os.sep)
    try:
        run_folder = parts[-1]
        task_folder = parts[-2]
        run_match = re.search(r'run(\d+)', run_folder)
        run = run_match.group(1).zfill(2) if run_match else "01"
        return task_folder, run
    except IndexError:
        return None, None

def parse_scan_id(fname):
    match = re.search(r'(tb\d+)', fname.lower())
    return match.group(1) if match else None

# === MAIN LOOP ===
for subject_folder in os.listdir(source_dir):
    subject_path = os.path.join(source_dir, subject_folder)
    if not os.path.isdir(subject_path):
        continue

    sub_id = subject_folder.lower()
    scan_id = scan_to_participant.get(float(sub_id))
    if not sub_id:
        print(f"Skipping {scan_id}: not in mapping")
        continue

    sub_bids = f"sub-{sub_id}"
    bids_func_dir = os.path.join(destination_dir, sub_bids, "func")
    bids_anat_dir = os.path.join(destination_dir, sub_bids, "anat")
    os.makedirs(bids_func_dir, exist_ok=True)
    os.makedirs(bids_anat_dir, exist_ok=True)

    # === Functional ===
    func_root = os.path.join(subject_path, "func")
    if os.path.exists(func_root):
        for task_folder in os.listdir(func_root):
            task_path = os.path.join(func_root, task_folder)
            if not os.path.isdir(task_path):
                continue

            for run_folder in os.listdir(task_path):
                run_path = os.path.join(task_path, run_folder)
                if not os.path.isdir(run_path):
                    continue

                task, run = parse_run_and_task(run_path)
                if not task or not run:
                    print(f"Skipping path: {run_path}")
                    continue

                for file in os.listdir(run_path):
                    if not file.endswith(('.nii', '.nii.gz')):
                        continue
                    if "localizer" in file.lower() or "flash" in file.lower():
                        continue

                    full_path = os.path.join(run_path, file)
                    file_scan_id = parse_scan_id(file)
                    if int(file_scan_id[2:6]) != scan_id:
                       continue

                    bids_name = f"{sub_bids}_task-{task}_run-{run}_bold.nii"
                    dst_path = os.path.join(bids_func_dir, bids_name)
                    shutil.copy(full_path, dst_path)
                    print(f"Copied: {file} → {dst_path}")

    # === Anatomical ===
    anat_dir = os.path.join(subject_path, "struct")
    if os.path.exists(anat_dir):
        for file in os.listdir(anat_dir):
            if not file.endswith(('.nii', '.nii.gz')) or "t1" not in file.lower() or "_co" in file:
                continue

            file_scan_id = parse_scan_id(file)
            if int(file_scan_id[2:6]) != scan_id:
                continue

            bids_name = f"{sub_bids}_T1w.nii"
            dst_path = os.path.join(bids_anat_dir, bids_name)
            full_path = os.path.join(anat_dir, file)
            shutil.copy(full_path, dst_path)
            print(f"Copied: {file} → {dst_path}")