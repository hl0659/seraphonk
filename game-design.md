# game-design.md — SERAPHONK

## High concept
Angelic Megabonk-like: solo seraph vs. fallen swarms. Top-down 2.5D arena with height. Movement is the weapon — Ultrakill-inspired dash/slide/slam to reposition and detonate.

## Core loop (Megabonk, from research)
1. Drop into procedurally-scattered arena: chests, shrines (stand-in-circle buff), vendors, Moai-like free blessing
2. Auto-attack weapons; player focuses on move/dodge/position + build choices
3. Kill → XP grace (grace pickups) → level → pick 1 of 3: new weapon (max 4) or upgrade / tome (max 4, global multipliers like Quantity)
4. Stackable Risk-of-Rain-style items from chests/vendors (gold cost scales)
5. Find Sanctum Gate (teleporter) → boss → next choir (stage). 10:00 timer → Wrath swarm (guaranteed-kill pressure, ends run cleanly)
6. Death = restart, meta: Silver Grace unlocks new weapons/tomes/items in pool + banish/reroll/pass counts

## Movement (Ultrakill-adapted)
Walk / Dash (Shift, i-frames, through enemies) / Dash-Jump (Shift+Space, keeps momentum, costs 2 stamina) / Slide (Ctrl, low friction, steerable, Slideways bonus) / Slide-Jump (preserve momentum cheap) / Slam (Ctrl in air: crash down, AoE + bounce) / Slam-storage bounce for height / Wall-nudge off arena pillars. Whiplash later: hook to elite/Hookpoint, pull 60 u/s equivalent.

Why it fits survivors: dodging dense swarms + grouping enemies (Megabonk swarm-stacking) then slamming for efficient chains.

## Angelic theme
You: Seraph recruit (halo = stamina ring, wings = dash trail). Enemies: Fallen cherubs, thorns, weepers. Pickups: grace (XP), manna (gold), blessings (items). Stages: 1 Outer Choir (garden ruins + pillars), 2 Sunken Nave (lava/acid skip-slide), 3 Throne Approach. Bosses: mini-herald every ~90s, gate-warden per stage.

## Progression sketch
Weapons: Halo Chakram (orbit), Trumpet Volley (nearest), Censer Swing (melee arc), Psalm Beams (pierce). Tomes: Quantity, Zeal (attack speed), Radius, Swiftness. Items: Feather (move speed stacking), Nail (contact damage), Tithe (gold→damage), Martyr (low-HP burst).

## Scope guardrails
M1: move + dash/slide/slam in empty arena with feel (trail/shake/hitstop). M2: auto-weapon + 1 enemy + XP/level. M3: waves/director + gate/boss + timer. M4: Blender pipeline sprites. M5: exe + CI green. No online, no 3D physics lib, no voice.
