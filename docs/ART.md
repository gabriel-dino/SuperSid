# Character art

- Asset: `assets/sid.png`
- Generated using the built-in `image_gen` tool with `transparent_background: true`.
- The original alpha channel is preserved. The renderer finds the opaque bounds and draws the image with nearest-neighbor filtering.
- Scenery, enemies, accessories, UI, and particles are drawn directly in Lua. Sound effects are synthesized at startup.

## Final generation prompt

```text
Use case: stylized-concept
Asset type: transparent 2D game character sprite
Primary request: A single full-body pixel art sloth hero named Sid, resembling Sid the sloth from Ice Age: tall thin curved neck, widely spaced eyes, buck teeth, large oval nose, lanky limbs, three long claws, pear shaped body, goofy friendly expression. In the simple chunky pixel silhouette style of the Google Chrome offline Dino game. Side profile facing right, standing neutral with legs slightly apart and arms forward ready for adventure. Monochrome warm ivory and charcoal only. Crisp blocky square pixels and clean silhouette, no antialiasing, no gradients. One character only, centered with comfortable transparent padding on all sides, no ground, no shadow, no text, no frame. This asset will be rendered small at about 45x65 pixels in a Lua platformer.
```
