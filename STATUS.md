# StoryScout iPhone and iPad App Status

Updated: 2026-09-06

## Current phase

Phase 5: native playback and foreground upload implemented; durable relaunch/background recovery remains in progress.

## Completed

- Product and technical plan approved.
- App and planning locations confirmed.
- Approved plan and progress log created.
- Existing plans, guidance, and repository status reviewed.
- Webapp and backend validation gates rerun successfully on 2026-09-05.
- Website UI/API parity specification completed.
- Local Xcode/SDK/project-generation tooling verified.
- Session-expiry and upload-renewal gaps documented.
- Backend six-hour session default, environment example, and regression coverage implemented and fully validated.
- Universal iOS 15 SwiftUI project, configuration, design foundation, API client, access-session model, and unit-test target created.
- Memory-only GUID access flow and approved final-30-minute countdown implemented.
- App and test targets compile successfully against the installed iOS SDK.
- Automatic signing now uses the same working Apple Development Team as AIRoadVision and persists through XcodeGen regeneration.
- Five session-countdown tests executed successfully on the iOS 26.2 simulator.
- Debug and Release use the live `https://story-scout.app/api/v1/` service; loopback is isolated to the Local configuration.
- Forced black-on-white appearance verified visually on an iPhone simulator in device Dark Mode.
- Eight total iOS tests pass and the optimized Release simulator build succeeds.
- Step 2 now includes the website-matched timer and Start/Pause/Resume/Stop/Record again controls.
- Native file-backed AAC/M4A recording engine and audio-interruption handling implemented with background-audio configuration.
- Ten total iOS tests pass and the optimized Release simulator build succeeds after recording implementation.
- Completed recordings can be played back locally, uploaded through the existing create/presigned-PUT/complete API workflow, retried without creating a second in-memory server record, and confirmed on a completion screen.
- Thirteen total iOS tests pass, including three mocked upload-protocol tests, and the optimized Release simulator build succeeds after upload implementation.
- All participant-access and recording action buttons use one consistent light-gray, black-text, equal-height style; paired actions divide their row evenly.
- Native iPhone/iPad launch screen displays `StoryScout` centered and `Developed by Vikrant` near the bottom safe area on white.
- Thirteen iOS tests still pass and the optimized Release simulator build succeeds after the UI and launch-screen changes.
- The standalone iPhone app source is published publicly at `https://github.com/tuachotu/storyscout-ios` with `main` as the default branch.

## In progress

- Validate microphone capture and screen-lock continuity on the user's physical iPhone.
- Persist the local upload queue and server recording identity across app termination.
- Add background URLSession transfer recovery and restart-safe completion handling.

## Pending

- Physical-device locked-screen validation.
- Durable background uploads and relaunch recovery.
- Compatibility testing.
- TestFlight and App Store release, subject to separate approval.
- Proper authentication, GUID persistence, and upload-link renewal.

## Physical-device validation pending

- The project has not been installed on a physical iPhone by Codex. The user can now select `VikrantIphone` in Xcode and press Run; Xcode may ask to register the StoryScout bundle identifier and create/select a development provisioning profile.
- A clean isolated app-start timing measurement remains pending; observed long waits were dominated by simulator boot/migration/install rather than work performed by StoryScout at launch.

## Authorization

Local implementation is approved. Git commits, remotes, pushes, production changes, external API writes, Apple account changes, TestFlight uploads, and App Store submission are not approved.

The user separately approved one local initial commit and creation/push of the public `tuachotu/storyscout-ios` repository on 2026-09-06. This does not authorize any other repository, deployment, or external-resource changes.
