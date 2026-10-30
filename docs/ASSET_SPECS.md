# Asset specs

GENERATED from `shared-data/assets.json` by `tools/gen_asset_docs.py`. Do not edit by hand.

Each entry is something the game needs that cannot be made from a terminal (3D models, art,
animation, sound, music). Hand these specs to an artist, or use them to search for properly
licensed assets. Every asset that comes in must be logged in `shared-data/assets.json` with its
source and license.

## Needed: nothing exists yet (15)

### Player character model (`ast_char_player_placeholder`)

- **Kind:** character_model
- **Spec:** Original cel-shaded anime-proportioned humanoid on an R15-compatible rig, so Roblox animations and layered accessories work. Two body builds. Swappable hair, outfit and accessory slots. Face as a texture atlas so expressions can change. Budget: 10k triangles or fewer, at most two 1024x1024 textures.
- **Shown until then:** Blocky R15-style rig built from plain parts, coloured from the character-creation choices.

### Hearthwick katana model (`ast_wpn_hearthwick`)

- **Kind:** weapon_model
- **Spec:** Katana about 5 studs long with a glowing wick-like line running down the blade and a lantern-shaped guard. Cel-shaded, 1.5k triangles or fewer, emissive strip for the glow that brightens on parry.
- **Shown until then:** Thin neon part for the blade plus a cylinder hilt.

### Lanternblade animation set (`ast_anim_lanternblade_moveset`)

- **Kind:** animation_set
- **Spec:** R15 animations: idle, run, sprint, jump, fall, land; light 1-4; heavy 1-2 plus charge hold; dash attack; air attack; guard hold, guard hit, parry; Flash Step in four directions; light and heavy hit reactions; stagger; knockdown and get-up; Wickflare; Cinder Rush; Eclipse Form transformation. Snappy anime timing that matches the windup/active/recovery numbers in movesets.json and abilities.json.
- **Shown until then:** Roblox default movement animations; attacks shown with simple procedural arm tweens and hit flashes.

### Lanternblade sound set (`ast_sfx_lanternblade`)

- **Kind:** sound_set
- **Spec:** Light and heavy swing whooshes, flame crackle, a bright satisfying parry clang, guard thud, dash whoosh, Wickflare release. Short and punchy, mixed to sit under the music.
- **Shown until then:** Silent until original or properly licensed sounds exist.

### Wickflare and lantern flame effects (`ast_vfx_wickflare`)

- **Kind:** vfx
- **Spec:** Crescent flame wave: orange core, white-hot edge, readable from every camera angle. Needs a low-particle version for phones on Low quality.
- **Shown until then:** Flat neon wedge part that travels forward and fades out.

### Eclipse Form transformation effect (`ast_vfx_eclipse_form`)

- **Kind:** vfx
- **Spec:** The player's shadow rises and wraps around them: dark violet outline, ember-orange rim light, an eclipse ring behind the head. Must never darken the screen or hide enemies.
- **Shown until then:** Violet outline highlight on the character.

### Gloamling model (`ast_enm_gloamling`)

- **Kind:** enemy_model
- **Spec:** Hunched dog-sized shadow quadruped with one ember eye and smoky edges. Silhouette must read clearly against night streets. 4k triangles or fewer.
- **Shown until then:** Dark grey block body with a neon orange ball for the eye.

### Gloamling animation set (`ast_anim_gloamling`)

- **Kind:** animation_set
- **Spec:** Idle, prowl, run, claw swipe with a clear 0.55 s wind-up pose, pounce (crouch and body glow), hit reaction, stagger, death fade.
- **Shown until then:** Procedural tweens: lean back on wind-up, lunge forward on attack.

### Gloamling sound set (`ast_sfx_gloamling`)

- **Kind:** sound_set
- **Spec:** Low growl, swipe hiss, pounce screech (this is the audio tell for the unblockable attack), fade-out whisper.
- **Shown until then:** Silent until original or properly licensed sounds exist.

### Lampeater boss model (`ast_enm_lampeater`)

- **Kind:** enemy_model
- **Spec:** Tall long-limbed Gloam (about 18 studs) whose ribcage is full of swallowed, still-glowing street lamps, the light source that keeps it readable. Spine shaped like a bent lamp post. 15k triangles or fewer.
- **Shown until then:** Tall dark block figure with neon spheres inside its chest.

### Lampeater animation set (`ast_anim_lampeater`)

- **Kind:** animation_set
- **Spec:** Idle, stalk, Lamp Swipe, Twin Swipe, lunge wind-up and lunge, Blackout Ring slam, Spat Lanterns, two phase-transition roars, stagger, defeat.
- **Shown until then:** Procedural tweens on the block model.

### Lampeater sound set (`ast_sfx_lampeater`)

- **Kind:** sound_set
- **Spec:** Glass-and-metal chime breathing, swipe whooshes, a rising hum before the lunge (audio tell), ring slam, lantern spit, phase roars.
- **Shown until then:** Silent until original or properly licensed sounds exist.

### Lampeater boss music (`ast_music_lampeater`)

- **Kind:** music
- **Spec:** Original boss track, 2-3 minute loop, with three intensity layers that crossfade on phase changes. Anime-action feel: strings, taiko, synth bass. Must be original or licensed for both Roblox and Steam.
- **Shown until then:** No music.

### Akeboshi harbor district environment (`ast_env_akeboshi_harbor`)

- **Kind:** environment
- **Spec:** Modern Japanese-inspired harbor district at night: shop fronts, vending machines, power lines, stone lanterns, the ferry terminal and the stopped clocktower. Cel-shaded with strong rim lighting. Must hold 30 fps on a 2021 mid-range phone on Low.
- **Shown until then:** Grey-box blocks generated from shared-data/maps/map_akeboshi_harbor.json.

### UI font (`ast_font_ui`)

- **Kind:** font
- **Spec:** Clean, very readable UI font with full Latin coverage (and later Japanese), readable on phones and TVs. The PC edition needs a separately licensed font, for example one under the SIL Open Font License.
- **Shown until then:** A Roblox built-in font.
