# TennisTracker

Strava for tennis: start a session on your Apple Watch, and we count your forehands, backhands and serves from your wrist movement.

**Phase 1 (this code): record and collect data.** The watch records motion at high rate during a tennis workout and sends it to the iPhone, where you can export it. No stroke detection yet. That's Phase 2, built on the data recorded here.

## What's here

| Folder | What it does |
|---|---|
| `Shared/` | Player profile, session metadata and sync keys, compiled into both apps |
| `WatchApp/` | Tennis workout (HealthKit), sensor recording to CSV, sends sessions to the phone |
| `iOSApp/` | Sign-up questions, session list and details, file export |
| `tools/plot_session.py` | Plots a recorded session so you can see the swings |

### How it works

1. **Sign-up (iPhone).** The player chooses which hand they play with and whether their backhand is one- or two-handed. The watch reports which wrist it's on and which side the crown is on, read from the watch settings. From this the app shows the expected detection quality.
2. **Session (watch).** Pick indoor or outdoor court to start an `HKWorkoutSession` with activity type `.tennis`. The workout keeps the app alive with the wrist down, records heart rate and calories, and saves to Apple Health.
3. **Recording.** On Series 8 and later and Ultra, `CMBatchedSensorManager` records the accelerometer at 800 Hz and device motion at 200 Hz. Older watches fall back to 100 Hz device motion.
4. **Sync.** When the session ends, the watch sends its files to the phone with `transferFile`. This works in the background and retries until delivered, after which the watch deletes its copy.

## Setup

1. Install **Xcode 15 or later** from the App Store, then run `sudo xcode-select -s /Applications/Xcode.app`.
2. Install XcodeGen with `brew install xcodegen`, then run `xcodegen generate` in this folder. Run it again whenever you add files or change `project.yml`.
3. In `project.yml`, set `DEVELOPMENT_TEAM` to your Apple Developer Team ID, and optionally change the `com.souravk` prefix in the bundle IDs. Then regenerate.
4. Open `TennisTracker.xcodeproj`, choose the **TennisTracker** scheme and your iPhone, and run. The watch app installs with it. You can also run the **TennisTrackerWatch** scheme directly on the watch.

You need real devices. The simulator has no motion sensors.

## Data format

Each session is a folder named by its UUID:

- **`meta.json`:** profile, watch placement, sensor rates, sample counts, heart rate, watch model. Dates are in Unix seconds.
- **`motion.csv`:** device motion, 200 Hz (100 Hz on the fallback path).
  - `t`: Unix time in seconds.
  - `user_a*`: user acceleration in g, with gravity removed.
  - `grav_*`: the gravity vector in g.
  - `rot_*`: rotation rate in rad/s.
  - `q_*`: attitude quaternion.
- **`accel.csv`:** raw accelerometer at 800 Hz in g, including gravity. Batched sensors only.

All values are in the watch's own frame. The axes are not mirrored for left- or right-wrist wear yet: Phase 2 does that, using `profile` and `placement` from `meta.json`.

Recordings are large, roughly 200 MB per hour with the 800 Hz stream. That's fine for data collection; Phase 2 will detect strokes on the watch and only keep the results.

## Collecting labeled data (to prepare for Phase 2)

1. Prop a phone on the fence and record video of the whole session.
2. Start the session on the watch. Then **tap the racket frame sharply against your free palm 3 times** in view of the camera. This creates a sync spike that shows in both the video and `accel.csv`.
3. Play normally: rallies, serves, and some non-strokes like bouncing the ball, picking it up, and walking.
4. Export the session from the iPhone (Session › Export all files) and AirDrop it to your Mac.
5. Run `python tools/plot_session.py <session-folder>` and check that the swings are visible.

Aim for sessions from several players, with both hands, both backhand styles, and the watch on both wrists.

## Roadmap

1. ~~Watch recording plus export~~ (this phase)
2. Mirror sensor data into one standard frame, then on-watch swing detection and rule-based forehand/backhand with a live counter
3. iPhone session stats and an Instagram Stories share card
4. Labeling tool and a Core ML stroke classifier (adds serve and volley)
5. Backend, social feed, Wear OS
