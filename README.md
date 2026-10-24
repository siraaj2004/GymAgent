# GYM AI — Your Personal Trainer (iOS)

Isolated project. It does NOT touch, edit, or depend on:
- Relationship AI Keyboard (`~/workspace/relationship-ai-keyboard/`)
- Second AI Agent (`~/workspace/second-ai-agent/`)
- Masai AI Engineer Job Cracker (`~/workspace/masai-ai-engineer-job-cracker/`)

## What is built (stage 1, real code — not a UI mock)

- **Onboarding** — 14 questions, one at a time, saved in SwiftData, never repeated.
  Sex can be skipped (nutrition then uses the mean Mifflin-St Jeor estimate).
- **Workout plan** — your exact PDF imported as `Resources/workout-plan.json`:
  5 training days, 71 exercises, 197 sets, 100 min/session, with sets, reps,
  rest and effort (RIR) exactly as printed. Days 6–7 are rest days.
  Monday = Day 1 … Friday = Day 5. The bundled JSON is the restore source;
  user edits are stored separately.
- **AI Coach** — AVFoundation camera + Apple Vision human-body pose
  (`VNDetectHumanBodyPoseRequest`), on-device only, skeleton points from real
  detections. Exercise-specific state machines for squat, push-up, lunge,
  bicep curl, shoulder press, lateral raise, Romanian deadlift, pull-up,
  dumbbell row, plank (timed) and leg raise. Other movements (machines, cables,
  most isolation) are explicitly **manual** — the app never pretends the camera
  tracked them. Low-confidence / occluded frames show "Unable to assess" and
  count nothing. Neck work is instructional only, never aggressive correction.
- **Voice coach** — AVSpeechSynthesizer, offline, with cooldowns, repeated-message
  suppression, mute, Bluetooth audio session, English / Telugu / Hindi /
  Mixed Telugu+English.
- **Nutrition** — Mifflin-St Jeor BMR, activity multiplier, modest goal
  adjustment, protein/carb/fat/fibre with assumptions shown and macros
  constructed to match the calorie target.
- **Food** — Indian food search, vegetarian filter, gram scaling, meal
  (breakfast/lunch/dinner/snacks), water, remaining-target suggestions.
  Photo/barcode estimation is NOT claimed as exact — it needs a nutrition
  API/model and is not bundled.
- **Reminders** — daily gym-time notification, 30-minute warning, rest-day
  message, completion message, 10-minute snooze. No guilt wording.
- **Progress** — weight log, completed workouts, total volume
  (sum of reps × weight across saved sets), heaviest saved set.
- **Privacy/offline** — pose on-device, no video upload by default, SwiftData
  local storage, export/delete to be added via SwiftData store management.
  Camera/mic/notification permissions are declared in `App/Info.plist`.

## What is NOT yet verified / NOT claimed

- **No IPA exists yet.** This VM has no macOS/Xcode/Swift, so no build or test
  run was possible here. The GitHub Actions workflow (`.github/workflows/build.yml`)
  runs the XCTest suite and, if green, builds the unsigned IPA. Do not use any
  IPA link until that workflow has actually produced an artifact — then check
  its byte size and `unzip -l` output.
- Tests in `Tests/GymAITests.swift` are real XCTest tests, but they have **not
  been executed** in this environment. They run on the macOS runner.
- Camera pose tracking, voice on a physical iPhone, and notification delivery
  have **not** been tested on a device yet. That is the next verification step
  after the IPA is built.
- Barcode scanning and photo meal estimation are not implemented as exact
  nutrition — see Food section above.

## Build (macOS + Xcode 16)

```bash
brew install xcodegen
xcodegen generate
open GymAI.xcodeproj
```

Run tests in Xcode (⌘U), or on CI via Actions → "GymAI tests and unsigned IPA".

## Install the unsigned IPA from Windows

1. Push this folder to a GitHub repo, run the workflow, download the
   `GymAI-unsigned-ipa` artifact.
2. Install with Sideloadly or AltStore using your free Apple ID.
   Free signing expires after 7 days — reinstall weekly.
3. On first launch: allow Camera, Notifications; complete onboarding once;
   open Workout → pick today's day → AI Coach for a supported exercise.

## Safety

Camera analysis cannot detect every error and never proves a movement is safe.
Heavy lifts use conservative feedback. Stop immediately for sharp pain,
dizziness, numbness or unusual symptoms and seek professional assessment.
