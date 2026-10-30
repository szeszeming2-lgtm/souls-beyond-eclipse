# Game design overview (draft for your approval)

Short version of the design. The full details live in `shared-data/` as data.
Everything here is original. Names, factions, places and story are new to this project.

## Premise

At 12:07 one afternoon, the sun over **Akeboshi City** turns black. For seven minutes every person
in the city falls asleep, except you. Shadows peel off the streets and start hunting anything that
glows. Your own shadow stops copying your movements and drags you out of harm's way.

When the light comes back, you can see what nobody else can: every person carries a small flame
(their **Kindle**), and the things in the dark (the **Gloam**) are souls whose flames went out.
The **Lantern Wardens** take you in, mostly to keep an eye on your shadow.

What really caused the eclipse, and why your shadow is alive, is the thread that runs through the
whole story.

## Design pillars
1. **Readable, fast combat.** Every attack has a visible and audible tell. Every attack can be
   avoided. Nothing hides the action.
2. **Challenging, never frustrating.** Difficulty can be changed any time, boss help is offered and
   optional, death costs nothing, and the next goal is always clear.
3. **Play your way.** Six fighting styles. Learn more later, respec any time, no trap builds.
4. **A world worth revisiting.** Soft level-sync keeps old regions rewarding; secrets in every
   region.
5. **Fair.** Server-authoritative, no pay-to-win, cosmetics only from playing.

## Core combat
- Light and heavy combo chains, Flash Step dodge (invulnerable for a moment), guard, parry and
  lock-on.
- **Spirit energy** fills from parries, perfect dodges and hits, and pays for abilities.
- **Q:** your weapon's special. **E / R:** your style's abilities. **F:** your ultimate
  transformation (Eclipse Form: your shadow wraps around you).
- Stagger has an immunity window afterward, hard crowd control is capped, and only a few enemies
  attack you at once. No stun-lock loops.

## Factions and fighting styles

| Faction | Style | Identity |
|---|---|---|
| Lantern Wardens | Lanternblade (katana) | Balanced melee, parry counters, flame arcs. **Phase 1 style.** |
| Skyreader Observatory | Starfletcher (bow) | Mark enemies with star-points, then link and detonate them |
| Omokage Troupe | Maskdancer (fans + masks) | Swap ancestral masks mid-combo to change stance and moveset |
| Paper Court | Foldcaller (talismans) | Fold paper familiars that scout, shield and swarm |
| Bellhold Monastery | Bellstriker (gauntlets) | Build resonance with clean hits, release it as shockwaves |
| The Unlit | Duskrunner (twin daggers) | Shadow-blink assassins with high mobility |
| Penumbral Synod | (enemy only) | Rulers of the Gloam who want a permanent eclipse |

## World (11 connected regions)

Akeboshi City → Ura-Akeboshi (the city's flooded mirror) → Amagiri, the Mistbound Capital →
The Thousand Stacks (archive maze) and Shirokane Peaks (frozen monastery) → The Inverse Tide
(an ink sea under a black sun) → Kurogane Caldera (volcanic war forges) → Tenkyu, the Floating
Palace → The Hakumei Rift (twilight dimension) → The Sun Below → The Corona Abyss (endgame).

Every region gets a hub, fast travel, a landmark, side quests, secrets, its own enemies, a boss and
story beats. Only Akeboshi Harbor has a map layout so far; the rest are concept entries.

## Story arcs (outline)
1. **Seven Minutes of Night (1–250).** The eclipse, your living shadow, joining the Wardens, your
   rival Yuzuki Tono, the Lampeater, and the discovery of Ura-Akeboshi.
2. **Lanterns in the Mist (251–700).** The hidden capital, the six-faction council, faction trials.
   A page has been erased from the Skyreaders' star charts. Someone predicted the eclipse, and
   someone on the council knew.
3. **The Silent Bell (701–1000).** Optional side arc: the Bellhold Monastery's great bell has gone
   silent. Yuzuki's companion story.
4. **Tide of Ink (1001–1700).** The Penumbral Synod invades. War in their realm and at the caldera
   forges. The Unlit become uneasy allies. A trusted figure's betrayal.
5. **Two Suns (1701–2000).** In the floating palace you face your own shadow and earn a second
   power by making peace with it rather than defeating it.
6. **Hakumei (2001–2700).** A final war across overlapping realms, ending at the dimming Sun Below
   and the truth about what an eclipse is.
7. **Corona (2701–3000).** Endgame: dungeons, raids, boss rush, secret bosses.

The main story only ever requires main quests (the validator enforces this).

## Progression
- Level cap 3000. About 5 hours to level 100, about 225 hours to 3000 with varied play (simulated
  in `tools/xp_sim`).
- Milestone rewards every 50 levels, with bigger ones at 100, 500, 1000, 1500, 2000, 2500 and 3000.
  Rewards are titles, skill points, loadout slots and cosmetics, never raw power spikes.
- Catch-up bonus for under-leveled and returning players. Grinding the same enemy gives less and
  less XP, so varied play is always faster.

## Originality note
The brief's example list (spirit swordsman, spirit archer, masked transformation fighter, hidden
spirit capital, desert fortress realm) lines up closely with the structure of one well-known anime.
To keep this game original, I kept the generic genre roles (swordsman, archer, summoner and so on)
but gave each faction its own concept: ancestral festival masks instead of monster masks,
astronomer-archers, origami summoners. I also changed the world: the enemy realm is an ink sea, not
a desert fortress. Please keep this in mind when adding ideas: borrow genres, not specifics.
