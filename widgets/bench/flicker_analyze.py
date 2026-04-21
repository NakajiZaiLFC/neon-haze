#!/usr/bin/env python3
"""
Flicker analysis tool — detects visual flicker in screen recordings.

Analyzes frame-to-frame differences in a video capture to quantify flicker:
  - Counts "flicker events" (consecutive changed frames)
  - Computes worst-case SSIM (structural similarity)
  - Outputs per-frame CSV for graphing

Pass criteria:
  flick_events_per_sec < 0.1  AND  worst_ssim > 0.98

Usage:
  python3 flicker_analyze.py <video_file> [--crop x,y,w,h] [--fps 60] [--csv output.csv]

Dependencies:
  pip install opencv-python scikit-image numpy
"""

import argparse
import csv
import json
import sys

try:
    import cv2
    import numpy as np
    from skimage.metrics import structural_similarity as ssim
    HAS_DEPS = True
except ImportError:
    HAS_DEPS = False


def analyze(path: str, fps: int = 60, crop: tuple = None,
            pixel_threshold: float = 3.0, ssim_critical: float = 0.95,
            min_run_frames: int = 2, csv_path: str = None) -> dict:
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        print(f"ERROR: Cannot open {path}", file=sys.stderr)
        return {}

    actual_fps = cap.get(cv2.CAP_PROP_FPS)
    if actual_fps > 0:
        fps = int(actual_fps)

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    print(f"Video: {path}")
    print(f"  FPS: {fps}, Total frames: {total_frames}")
    if crop:
        print(f"  Crop: x={crop[0]}, y={crop[1]}, w={crop[2]}, h={crop[3]}")

    prev = None
    run = 0
    runs = []
    worst_ssim = 1.0
    rows = []
    idx = 0
    changed_count = 0

    while True:
        ok, frame = cap.read()
        if not ok:
            break

        if crop:
            x, y, w, h = crop
            frame = frame[y:y+h, x:x+w]

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY).astype(np.float32)

        if prev is not None:
            diff = float(np.mean(np.abs(gray - prev)))
            s = float(ssim(prev, gray, data_range=255))
            worst_ssim = min(worst_ssim, s)
            changed = diff >= pixel_threshold

            rows.append([idx, idx / fps, round(diff, 3), round(s, 5), int(changed)])

            if changed:
                run += 1
                changed_count += 1
            else:
                if run >= min_run_frames:
                    runs.append(run)
                run = 0

        prev = gray
        idx += 1

        if idx % 500 == 0:
            print(f"  processed {idx}/{total_frames} frames...", file=sys.stderr)

    cap.release()

    if run >= min_run_frames:
        runs.append(run)

    duration = max(idx / fps, 1e-9)

    if csv_path:
        with open(csv_path, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["frame_idx", "time_sec", "y_diff", "ssim", "changed"])
            writer.writerows(rows)
        print(f"  CSV written: {csv_path}")

    result = {
        "file": path,
        "total_frames": idx,
        "duration_sec": round(duration, 2),
        "fps": fps,
        "changed_frames": changed_count,
        "changed_pct": round(100 * changed_count / max(idx - 1, 1), 2),
        "flick_events": len(runs),
        "flick_events_per_sec": round(len(runs) / duration, 4),
        "max_flick_run": max(runs) if runs else 0,
        "worst_ssim": round(worst_ssim, 5),
        "pass_flick_rate": len(runs) / duration < 0.1,
        "pass_ssim": worst_ssim > 0.98,
        "pass": len(runs) / duration < 0.1 and worst_ssim > 0.98,
    }

    return result


def print_result(r: dict):
    if not r:
        return
    print(f"\n{'='*50}")
    print(f"  File:                {r['file']}")
    print(f"  Duration:            {r['duration_sec']}s ({r['total_frames']} frames @ {r['fps']}fps)")
    print(f"  Changed frames:      {r['changed_frames']} ({r['changed_pct']}%)")
    print(f"  Flicker events:      {r['flick_events']}")
    print(f"  Flicker rate:        {r['flick_events_per_sec']}/sec {'PASS' if r['pass_flick_rate'] else 'FAIL'}")
    print(f"  Max flicker run:     {r['max_flick_run']} frames")
    print(f"  Worst SSIM:          {r['worst_ssim']} {'PASS' if r['pass_ssim'] else 'FAIL'}")
    print(f"  Overall:             {'PASS' if r['pass'] else 'FAIL'}")
    print(f"{'='*50}")


def main():
    if not HAS_DEPS:
        print("Missing dependencies. Install with:")
        print("  pip install opencv-python scikit-image numpy")
        sys.exit(1)

    parser = argparse.ArgumentParser(description="Analyze screen recording for flicker")
    parser.add_argument("video", help="Path to video file (mkv/mp4)")
    parser.add_argument("--crop", help="Crop region: x,y,w,h", default=None)
    parser.add_argument("--fps", type=int, default=60, help="Override FPS (default: auto-detect)")
    parser.add_argument("--csv", help="Output per-frame CSV", default=None)
    parser.add_argument("--json", help="Output results as JSON", action="store_true")
    parser.add_argument("--threshold", type=float, default=3.0, help="Pixel diff threshold")
    args = parser.parse_args()

    crop = None
    if args.crop:
        crop = tuple(int(x) for x in args.crop.split(","))
        if len(crop) != 4:
            print("ERROR: --crop must be x,y,w,h", file=sys.stderr)
            sys.exit(1)

    result = analyze(args.video, fps=args.fps, crop=crop,
                     pixel_threshold=args.threshold, csv_path=args.csv)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print_result(result)


if __name__ == "__main__":
    main()
