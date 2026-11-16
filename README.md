# Ani City: Lace & Mayhem

A playable iPhone prototype of a small open city. Ani is a modeled character — blonde twin-tails, blue eyes, black off-shoulder lace dress — not a stack of capsules. The city, skin, lace, brick, and wet asphalt use baked PBR textures. Lighting is Three.js: clearcoat car paint, bloom, filmic tone mapping, and a night reflection probe.

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

- A few blocks: roads, lights, a graffiti hood, Lace Burger, and one house with a driveway
- Day/night, starting at night, with light rain
- Modeled Ani and pedestrians, arcade cars, traffic, police
- Touch controls and standard gamepads
- One save slot

## Not in this slice

The rest of the city, guns, companions, weather systems beyond the rain, and real Unreal Engine rendering. The look is a PBR Three.js scene aimed at a night-city read, not Nanite or Lumen.
