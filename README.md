# Ani City: Lace & Mayhem

A playable iPhone prototype of a small open city. Ani is the supplied adult woman, restyled with blonde twin-tails, blue eyes, and an opaque black off-shoulder lace dress. Rook, the other pedestrians, and the police are CC0 MakeHuman rigs (see CREDITS.md). Walk, jog, run, and idle clips drive everyone, and rain darkens skin and cloth. The black sports car is a CC0 coupe with a windscreen rain shader, wipers, a steering wheel that follows steer input, and a door swing when you get in or out. Roads stay wet, with puddles. Lighting is Three.js: clearcoat, bloom, filmic tone mapping, and a night reflection probe.

This is a vertical slice. It is landscape-only and targets iOS 16+.

## Play

Touch controls sit on the screen: joystick to move, drag the right side to look, RUN/GAS, BRK, HB, ACT, HOR, and MAP.

A paired DualSense or other standard gamepad is read through the browser Gamepad API:

| Input | On foot | Driving |
| --- | --- | --- |
| Left stick | Move | Steer |
| Right stick | Camera | Camera |
| R2 | Sprint | Gas |
| L2 | — | Brake |
| Cross | Action | Exit |
| Triangle or Options | Phone | Phone |
| Square | — | Handbrake |
| R1 / L1 | Horn | Horn |

ACT takes a car, orders at Lace Burger, or buys Lace House ($750). The phone saves money, health, and where you are standing. Stealing, hard crashes, and hitting people raise the wanted level. Police chase with sirens, traffic pulls aside, and staying out of sight drops a star.

## Unsigned IPA

GitHub Actions builds this React app, wraps it with Capacitor, and runs `xcodebuild` with signing turned off. The artifact is `AniCity.ipa`. appdb re-signs it. No Apple certificate is used.

```bash
npm ci
npm run build
npx cap sync ios
bash scripts/build-unsigned-ipa.sh
```

The last command needs a Mac with Xcode and CocoaPods.

## In this slice

- Several blocks: roads, lights, a graffiti hood, extra shop rows, Lace Burger, and one house with a driveway
- Street lamps, benches, and puddles
- Day/night, starting at night, with rain streaks on glass, wipers, and wet skin and cloth
- Rigged Ani, pedestrians, and police, with LODs past 16 meters
- One detailed coupe plus arcade traffic. Getting in opens the door, then a seated pose. The wheel turns with steering
- Touch controls and standard gamepads
- One save slot

## Size

The unsigned IPA is tens of megabytes, not the 3 GB end of a texture dump. The two character GLBs and the coupe are about 44 MB uncompressed, which is the bulk of the app. A multi-gigabyte pack of 4K scans would blow past what this GitHub builder, appdb sideload, and an iPhone's memory can reliably chew, and the skinned crowd would drop frames before the extra texels helped. High detail is reserved for Ani and the hero car. Everyone else shares those rigs and drops to a tiny proxy when far away.

## Not in this slice

This is not Nanite, Lumen, MetaHuman, or strand hair. Skin uses sheen as a stand-in for subsurface scattering. Eyes are a clearcoat cornea over the painted face, not a full refraction shader. Ani's black lace dress is a restyle of the CC0 suit mesh plus an overskirt, because that rig does not include a separate off-shoulder dress. The coupe's outer door is modeled into the body, so the swing is clearest on the simpler cars. Hands reach the wheel with a posed grip, not IK. There is no Mixamo data. Guns and the rest of a full city are still out. Rook, an adult companion in everyday clothes, follows Ani on foot and rides in the passenger seat.
