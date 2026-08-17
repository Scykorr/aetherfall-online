# Character art pipeline prototype

This document defines the VIS-003 presentation boundary and VIS-004 animation pipeline for player characters and the Training Wisp. The current models and animation clips are original procedural prototypes, not production assets.

## Authority boundary

```text
authoritative replicated entity
        -> gameplay/network root
        -> presentation scene
        -> VisualRoot
        -> CharacterModel / EquipmentRoot / VFXRoot
```

Movement, targeting, combat, death, respawn and ownership remain outside model scenes. Presentation consumes replicated state and never produces authoritative outcomes.

## Scale

- `1 Godot unit` is approximately `1 meter`.
- Humanoid target height: `1.8–2.0 m`, including the head.
- Small Training Wisp target: `1.0–1.5 m` apparent height and `1.4–2.0 m` readable footprint.
- Model origins remain at ground/actor origin; floating offsets belong inside `VisualRoot`.
- Imported models must be checked beside the VIS-002 doorway, trees, road, target ring and existing collision shapes.

Do not rescale gameplay roots to correct art scale. Normalize imported model scale inside `CharacterModel` or during import.

## Required hierarchy

Player presentation:

```text
PlayerPresentation
├─ VisualRoot
│  ├─ CharacterModel
│  ├─ EquipmentRoot
│  │  ├─ RightHand
│  │  ├─ LeftHand
│  │  ├─ Head
│  │  └─ Back
│  └─ VFXRoot
└─ DebugRoot
```

Monster presentation follows the same `VisualRoot`, `CharacterModel`, `EquipmentRoot`, `VFXRoot` and `DebugRoot` boundary. Monster attachment points may be archetype-specific.

Gameplay collision, `NavigationAgent3D`, targetable areas, selection rings and network interpolation must remain outside presentation scenes.

## Model swapping

`CharacterModel` is the replaceable model mount. A production GLB replaces its prototype mesh children without changing the parent presentation scene or gameplay entity.

Before accepting a GLB:

1. verify meters, origin, forward direction and ground contact;
2. verify readable silhouette at the normal 3/4 camera distance;
3. map production material slots to the approved shared palette;
4. connect attachment markers to skeleton bones with `BoneAttachment3D` where needed;
5. keep `EquipmentRoot` and `VFXRoot` public scene contracts stable;
6. test local, remote and lifecycle presentation through replicated state.

The current Godot forward direction is `+Z`, matching player controller rotation.

## Animation controller

Both presentation scenes expose the same presentation-only controller and clip contract:

- `idle`
- `run`
- `attack_basic`
- `hit`
- `death`
- `respawn`

The prototype clips animate only `VisualRoot/CharacterModel`. They never move the gameplay root, write HP, apply damage, complete cooldowns or invoke authoritative callbacks. Production skeletal clips can replace them while preserving the names and controller API.

Replicated input mapping:

| Authoritative input | Presentation response |
|---|---|
| snapshot velocity is nearly zero | `idle` |
| snapshot velocity is non-zero | `run` and visual-only facing |
| confirmed combat event attacker | `attack_basic`, facing the confirmed target |
| confirmed combat event target | `hit` |
| replicated `life_state == DEAD` | `death` |
| replicated transition `DEAD -> ALIVE` | `respawn`, then locomotion |

Priority is `DEAD > HIT > ATTACK > locomotion`. Hit may interrupt attack; death interrupts everything. Attack and hit requests are ignored while dead. Repeated snapshots settle safely into the replicated lifecycle and locomotion state. Animation completion only chooses the next presentation clip.

The event router consumes the existing confirmed combat-event signal and resolves local players, remote players and monsters through the presentation registry. Monster movement uses replicated velocity; its attack is not inferred from a local timer or animation state.

## Skeleton expectations

The procedural VIS-004 clips do not require a skeleton. Production humanoids should use one reusable compatible rig per body family where practical.

Guideline humanoid rig:

- approximately `45–70` deform bones for the full-quality body;
- no facial rig in the first combat prototype;
- no gameplay logic in animation callbacks;
- root motion must not own authoritative position;
- bone names use stable `PascalCase` semantic names;
- attachment bones/markers remain stable across equipment-compatible models.

Monster rigs should use only the bones needed by the silhouette, normally `15–40` for a small creature prototype. The Training Wisp can begin with a compact bespoke rig later in VIS-004.

## Materials and textures

Prototype player surfaces use four shared families: cloth, leather, accent and skin. Training Wisp uses core, fin and aether accent.

Production guideline per normal character:

- `2–3` material slots preferred, `4` maximum without measured justification;
- one body/equipment atlas strategy per quality tier where practical;
- one primary texture set plus controlled shared masks;
- opaque materials by default;
- transparent character surfaces only for small, budgeted accents;
- no per-character realtime light;
- color variation through instance parameters or a shared palette, not duplicated materials.

Suggested near-character texture target is one `2048²` body/equipment set; mid/far tiers may use reduced mip residency or atlases. Bosses require separate measured budgets.

## Geometry and performance guidelines

These are starting targets for a future 50v50 plus boss scenario, not final absolutes:

| Asset | Near triangles | Mid triangles | Far triangles | Material slots | Bones |
|---|---:|---:|---:|---:|---:|
| Player body + baseline gear | 20k–35k | 8k–15k | 2k–5k | 2–3 | 45–70 |
| Small monster | 8k–20k | 3k–8k | 1k–3k | 1–3 | 15–40 |
| Boss | measured per encounter | measured | strong silhouette proxy | 3–5 | 40–100 |

- Cap active character lights at zero by default; VFX lighting is separately budgeted and quality-scalable.
- Keep character transparency below roughly 10% of visible silhouette area unless measured.
- Design at least near/mid/far geometry or equivalent visibility reductions.
- Merge the procedural prototype parts before treating them as a load-test asset; their current node/draw-call count is for pipeline validation only.
- Shadow casting, animation update rate and accessory visibility must support distance reduction.
- Future animation LOD should reduce update frequency at mid distance, disable minor hit accents at far distance and use a silhouette-safe idle proxy outside combat relevance.

## Attachment points

- `RightHand`: weapons/tools held by the character's right hand.
- `LeftHand`: off-hand equipment.
- `Head`: helmets and head presentation.
- `Back`: sheathed equipment, capes or back items.

Anchors are presentation-only. They do not grant equipment ownership, stats, attacks or hit detection. Future rigged models should drive them from bones while preserving these names.

## Naming conventions

- Scene files and scripts: `snake_case`.
- Scene/class roots: `PascalCase`.
- Stable hierarchy nodes and attachment points: `PascalCase`.
- Prototype mesh nodes use semantic names such as `Torso`, `FinLeft` and `CrownCenter`.
- Do not encode item IDs, stats or gameplay authority in model node names.

## Copyright and provenance

Do not use, extract, trace, transform or redistribute Royal Quest models, textures, rigs, animations or characters. External production assets require recorded commercial-compatible licenses and provenance before entering the repository.

The VIS-003 prototypes use only Godot primitives and project-authored materials.
