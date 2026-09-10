# Nori — Known Issues

## Evolution stage 2 has no real art yet (frontend placeholder in place)

`Pet.stage` already has two values (`baby`, `evolution1` — see `lib/models/pet.dart`
and FEATURES.md §6), and `PetRepository.syncEvolution` correctly promotes a pet once the
user's level crosses `evolutionLevelThreshold`. But there is no actual second-stage
character art: `nori_front/side/back.png` and the `nori_breathing/frame_*.png` sequence
are all extracted from real photography/video of a physical prop (see
`nori_breathing_sprite.dart`), not vector illustration — a true "evolved" look needs new
footage of that same prop, not something that can be drawn or generated in code.

Until that footage exists, `evolution1` reuses the exact same sprite, scaled up slightly
and given a warm mustard glow + a few sparkle accents (`NoriRoomStage`'s `_EvolvedAura`,
and the matching glow in `EvolutionScreen`), so evolving reads as "something changed"
instead of silently doing nothing. This is a deliberate stand-in, not a design decision —
when real stage-2 art lands, swap it in at both call sites (`NoriRoomStage.stage` and
`EvolutionScreen`) and drop the aura treatment.
