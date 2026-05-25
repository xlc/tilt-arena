# Game Center Achievement Artwork

Production achievement artwork for App Store Connect lives in `final/`.

Apple's App Store Connect achievement reference currently requires each
localized achievement image to be `.jpeg`, `.jpg`, or `.png`, exactly
`1024 x 1024` pixels, at least `72 ppi`, and RGB.

Validate the final assets before upload:

```bash
scripts/validate-game-center-achievement-assets
```

| Achievement ID | Display name | Points | Asset |
| --- | --- | ---: | --- |
| `com.xlc.tiltarena.achievement.first_run` | First Vector | 25 | `final/first-run.jpg` |
| `com.xlc.tiltarena.achievement.first_weapon_orb` | Orb Contact | 25 | `final/first-weapon-orb.jpg` |
| `com.xlc.tiltarena.achievement.first_enemy_clear` | First Clear | 25 | `final/first-enemy-clear.jpg` |
| `com.xlc.tiltarena.achievement.first_chain_reaction` | Chain Ignition | 50 | `final/first-chain-reaction.jpg` |
| `com.xlc.tiltarena.achievement.combo_10` | Combo 10 | 100 | `final/combo-10.jpg` |
| `com.xlc.tiltarena.achievement.combo_50` | Combo 50 | 100 | `final/combo-50.jpg` |
| `com.xlc.tiltarena.achievement.survive_60` | One-Minute Line | 100 | `final/survive-60.jpg` |
| `com.xlc.tiltarena.achievement.score_100000` | Six-Figure Signal | 100 | `final/score-100000.jpg` |
