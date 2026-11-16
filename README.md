# Ani City: Lace & Mayhem

Playable iPhone prototype of a small open city. Ani — blonde twin-tails, blue eyes, black off-shoulder lace dress — can walk, steal cars, pick up cash, eat, buy one house, and run from the police.

This is a vertical slice, not the full city from the design notes. Landscape only. iOS 16+.

## Play

On-screen controls sit on the left (joystick) and right (GAS/RUN, BRK, HB, ACT, HOR, MAP). Drag the right side of the screen to look.

A paired PS5 DualSense or other MFi controller uses Apple's GameController extended gamepad:

| Input | On foot | Driving |
| --- | --- | --- |
| Left stick | Move | Steer |
| Right stick | Camera | Camera |
| R2 | Sprint | Gas |
| L2 | — | Brake / reverse |
| Cross / A | Action | Exit |
| Triangle / Y or Options | Phone | Phone |
| Square / X | — | Handbrake |
| R1 / L1 | Horn | Horn |
| Right stick click | Recenter camera | Recenter camera |

On a DualSense the light bar idles purple and flashes red/blue while you're wanted. The adaptive triggers load up on the gas and resist on the brake.

The phone (MAP) shows the city, cash, and a save button. The world keeps moving while it's open. ACT at Lace Burger buys food and heals. ACT at Lace House buys it ($750) or, once you own it, rests and saves. One save slot stores money, health, and where you're standing.

Crimes (car theft, hard crashes, hitting people) raise the star meter. Police spawn with sirens, traffic pulls aside, and staying out of sight drops a star. Getting grabbed or dropping to 0 health dumps you at the impound lot, or at the house if you own it, and takes a cut of your cash.

## Unsigned IPA

GitHub Actions (`.github/workflows/unsigned-ipa.yml`) builds on a macOS runner with XcodeGen and `xcodebuild`, signing turned off, then zips `Payload/AniCity.app` into `AniCity.ipa`.

- Pull requests and manual runs upload **AniCity.ipa** as an artifact.
- Pushes to `main` also attach that IPA to a prerelease tagged `v0.1.<run number>`.

No Apple certificate is embedded. [appdb](https://appdb.to) (or another sideload tool) re-signs it for your phone. Install on an iPhone running iOS 16 or later and rotate to landscape.

To build the same IPA on a Mac:

```bash
brew install xcodegen
bash scripts/build-unsigned-ipa.sh
```

The project file is generated from `project.yml`. Do not commit `AniCity.xcodeproj`.

## In this slice

- A few blocks: roads and lanes, traffic lights, downtown towers, a graffiti hood, Lace Burger, and Lace House with a driveway
- Day/night cycle, starting at night
- Ani on foot, third-person camera
- Sports car, sedan, and beater, plus traffic and police cruisers. Arcade driving, collisions, and damage
- Lane traffic that stops for red lights and yields to sirens. Pedestrians
- Wanted stars, chase, escape, busted / wasted
- Cash pickups, food that heals, one buyable home
- Phone HUD with minimap, money, and stars
- Touch controls and DualSense / MFi
- One save slot

## Not in this slice

Multiple districts, weather, a full vehicle roster, guns, companions, interiors beyond the burger counter and the house, missions, phones-as-social-media, and anything outside a straight action game.
