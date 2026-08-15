# Aetherfall Online — prototype art direction

This document defines the VIS-001 look-development baseline. It is a production guide, not a promise of final asset quality. The accompanying test scene is `res://scenes/visual_tests/art_direction_test.tscn`.

## 1. Visual pillars

1. **Read at a glance.** Silhouette, value and color separation communicate before surface detail.
2. **Weathered wonder.** Familiar natural forms are interrupted by restrained, original aetheric shapes rather than ornate fantasy clutter.
3. **Bold masses, quiet surfaces.** Large shapes carry identity; painterly color variation should support them without visual noise.
4. **Gameplay first.** Characters, monsters, paths, blockers and telegraphs remain legible from the normal 3/4 camera.
5. **Built to scale.** Shared materials, opaque geometry and reducible detail support crowds, bosses and scalable effects.

The prototype motif is a **wind-worn upland after an aether rain**: warm ochre paths and masonry contrast with cool teal vegetation and violet hostile crystal growth. This is an original project direction. External games may inform only broad readability and genre expectations.

Priority: **readability over micro-detail**.

## 2. Shape language

| Family | Primary shapes | Reading goal |
|---|---|---|
| Player/allies | Upright taper, broad upper body, clear head and facing wedge | Stable, capable, directional |
| Hostile creatures | Low offset mass, outward spikes, asymmetric accent | Unfamiliar and immediately non-humanoid |
| Traversable ground | Broad horizontal planes and soft curves | Calm visual rest area |
| Natural blockers | Rounded stacked masses with uneven scale | Solid but not architectural |
| Architecture | Thick verticals, shallow arches, beveled-looking stepped profiles | Human-made landmark and scale anchor |
| Danger/hostile accents | Pointed diamonds, wedges and radial shapes | Urgency without relying only on red |

Avoid thin silhouette noise at gameplay distance. Small protrusions must either change the outline meaningfully or be removed.

## 3. Proportions

Characters use mildly exaggerated heroic proportions: a slightly enlarged head and hands, broad shoulder mass, short readable limb segments and a stable foot footprint. The VIS-001 mannequin is only a scale/silhouette proxy; VIS-002 owns the actual placeholder character.

Monsters should differ from players in height, center of mass and footprint. The VIS-001 crystal-backed creature is low and wide so it cannot be mistaken for a remote player. VIS-003 owns its production placeholder.

## 4. Material philosophy

Use a small shared palette before unique textures:

| Material | Prototype color/value | Surface intent |
|---|---|---|
| Ground | muted moss, medium-dark | matte visual rest area |
| Road/soil | warm ochre, medium-light | movement corridor and character contrast |
| Stone | warm grey, medium | quiet blocker/architecture base |
| Vegetation | cool teal, medium-dark | grouped graphic foliage |
| Architecture | pale sandstone, light | landmark and door-scale frame |
| Player | warm ivory with blue facing accent | highest local value, friendly readability |
| Monster accent | violet/magenta | hostile focal accent, limited emission later |

Prototype materials are opaque `StandardMaterial3D` resources with high roughness. Future painterly texture work should use low-frequency value variation, restrained edge accents and reusable trim/atlas layouts. Avoid noisy photo detail, excessive normal intensity and one material per prop.

## 5. Environment density

- Preserve calm ground around combatants: roughly one character-width of uncluttered silhouette space where encounters are expected.
- Group vegetation into clusters with deliberate gaps; do not distribute equal noise everywhere.
- Use one dominant landmark per camera frame, supported by smaller repeated props.
- Keep road/path values distinct from adjacent ground even when hue perception is limited.
- Tall foreground occluders need fade, cutaway or careful placement in later environment work.

VIS-001 uses a sparse composition to test separation. VIS-006 owns full greybox polish and density iteration.

## 6. Lighting

Baseline lighting is a readable overcast-sun mix:

- one warm directional key at an oblique angle;
- cool, moderate ambient fill so shadowed faces do not collapse;
- soft sky color distinct from the ground;
- restrained tonemapping with no crushed blacks or clipped character highlights;
- shadows used to ground large forms, not to create cinematic darkness.

The lighting must work while the existing camera orbits. Do not paint visibility for one hero angle. Character-vs-ground separation should survive both lit and shadowed areas.

## 7. Character readability

- Target an approximately 1.8–2.0 m player height.
- Preserve a clear head/torso/feet rhythm at the normal 10–14 m camera distance.
- Use the brightest neutral value on the player placeholder, with a small saturated facing accent.
- Keep the ground immediately behind typical player positions darker or more muted.
- Remote variation should change controlled accent regions, not create unique materials for every player.

## 8. Monster readability

- Change both silhouette and center of mass; color alone is insufficient.
- Reserve outward points and a violet accent family for the initial hostile language.
- Keep target rings and HP UI separate presentation layers driven by authoritative replicated state.
- Dead, selected and damaged visuals must follow authoritative lifecycle/combat state in later tasks.

## 9. VFX readability

- Telegraph shape, timing and placement must carry meaning before particle decoration.
- Friendly, hostile and environmental effects need distinct shape/value behavior and accessibility checks.
- Essential telegraphs survive the lowest quality tier; decorative trails, sparks and distortion reduce first.
- Prefer short opaque/additive accents over large overlapping transparent sheets.
- Never let animation or VFX completion apply damage, death, cooldown completion or loot. Presentation reacts to server-confirmed events/state.

VIS-001 contains no combat VFX. VIS-005 and VIS-008 own implementation and budgets.

## 10. Scale rules

Use metric logic: **1 Godot unit = approximately 1 meter**.

| Reference | Target size |
|---|---|
| Player | 1.8–2.0 m tall; 0.8–1.0 m gameplay footprint |
| Small monster | 1.0–1.6 m tall; 1.4–2.2 m footprint |
| Standard door opening | 1.4–1.8 m wide; 2.4–2.8 m tall |
| Single-storey wall | 3.2–4.0 m tall |
| Small tree | 5–7 m tall; canopy 3–5 m wide |
| Main road | 4–6 m wide |
| Combat lane for groups | 8–12 m clear width |
| Small rock blocker | 1–2.5 m wide; 0.7–1.8 m tall |

Measure assets against player, door and road references in the same scene before approval. Apparent scale from the gameplay camera matters alongside numeric dimensions.

## 11. Performance constraints

The future stress case is 50v50 players plus a boss, monsters and VFX. VIS-001 does not claim to meet that load; it selects a direction that can be reduced predictably.

Initial envelope:

- prefer 1–3 shared surface materials per character archetype and atlas compatible variation;
- use one shadow-casting directional light as the baseline;
- make additional local lights exceptional and quality-scalable;
- keep most environment geometry opaque;
- design characters and large props for at least near/mid/far LODs or equivalent visibility ranges;
- collapse distant character accessories and simplify distant silhouettes;
- use shared meshes/materials and instancing for repeated vegetation and rocks;
- budget transparent combat layers by priority and screen coverage;
- keep screen-space effects optional and never necessary for gameplay information;
- avoid per-frame material duplication and presentation allocations.

The prototype scene intentionally uses six main surface families, one directional light, no particles, no transparent vegetation and no post-processing dependency. Its many primitive nodes are acceptable for look development, but production clusters should be instanced/merged and measured.

## 12. Forbidden and copyright rules

- Do not use, extract, reconstruct, transform, trace or redistribute Royal Quest models, textures, animations, maps, UI, icons, sounds, effects, data, characters, monsters, locations, architecture or branding.
- Do not create confusingly similar substitutes.
- Royal Quest is only a high-level benchmark for readability, scale and MMORPG genre feel.
- Shipped assets must be original or have documented commercial-compatible licenses.
- Record source, author, license and modification requirements before adding any third-party asset.
- Godot primitives and project-authored procedural resources are preferred for prototypes.

The VIS-001 scene uses only Godot primitives, built-in rendering resources and project-authored colors. It contains no downloaded or extracted assets.
