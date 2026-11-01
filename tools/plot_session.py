"""Plot a TennisTracker session to eyeball the swings.

Usage:
    pip install pandas matplotlib
    python tools/plot_session.py path/to/session-folder

The folder should contain motion.csv (and accel.csv / meta.json if available).
Swings show up as sharp spikes in rotation speed; the dashed line is a naive
threshold that Phase 2 will replace with real detection.
"""

import json
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

SWING_THRESHOLD = 8.0  # rad/s, rough starting point
REFRACTORY_S = 0.7


def naive_swings(t: np.ndarray, rot_mag: np.ndarray) -> list[float]:
    swings, last = [], -np.inf
    for i in range(1, len(rot_mag) - 1):
        is_peak = rot_mag[i] >= rot_mag[i - 1] and rot_mag[i] > rot_mag[i + 1]
        if is_peak and rot_mag[i] > SWING_THRESHOLD and t[i] - last > REFRACTORY_S:
            swings.append(t[i])
            last = t[i]
    return swings


def main(folder: Path) -> None:
    motion = pd.read_csv(folder / "motion.csv")
    t0 = motion["t"].iloc[0]
    t = motion["t"].to_numpy() - t0
    rot = motion[["rot_x", "rot_y", "rot_z"]].to_numpy()
    rot_mag = np.linalg.norm(rot, axis=1)
    swings = naive_swings(t, rot_mag)

    title = folder.name
    meta_path = folder / "meta.json"
    if meta_path.exists():
        meta = json.loads(meta_path.read_text())
        profile = meta.get("profile") or {}
        title += (
            f"  |  plays {profile.get('playingHand', '?')}, {profile.get('backhand', '?')} BH, "
            f"watch on {meta['placement']['wrist']} wrist  |  {meta['deviceMotionHz']:.0f} Hz"
        )

    accel_path = folder / "accel.csv"
    rows = 3 if accel_path.exists() else 2
    fig, axes = plt.subplots(rows, 1, sharex=True, figsize=(14, 3 * rows))

    axes[0].plot(t, rot_mag, lw=0.6)
    axes[0].axhline(SWING_THRESHOLD, ls="--", c="gray")
    for s in swings:
        axes[0].axvline(s, c="red", alpha=0.3)
    axes[0].set_ylabel("|rotation| rad/s")
    axes[0].set_title(f"{title}\n{len(swings)} candidate swings (naive)")

    for i, axis in enumerate("xyz"):
        axes[1].plot(t, rot[:, i], lw=0.6, label=f"rot_{axis}")
    axes[1].set_ylabel("rotation rad/s")
    axes[1].legend(loc="upper right")

    if accel_path.exists():
        accel = pd.read_csv(accel_path)
        ta = accel["t"].to_numpy() - t0
        mag = np.linalg.norm(accel[["ax", "ay", "az"]].to_numpy(), axis=1)
        axes[2].plot(ta, mag, lw=0.4)
        axes[2].set_ylabel("|accel| g (800 Hz)")

    axes[-1].set_xlabel("seconds since start")
    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
