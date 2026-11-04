# Super Sid level files

The Level editor saves `.sidlevel` files as UTF-8 text. Share these files through any file-sharing method;
the recipient imports them from Contrib levels. No account or server is required.

The format uses one record per line and **tab-separated** fields. Windows and Unix line endings are supported.
The first line must be `SUPER_SID_LEVEL`, a tab, then `1`, `2` or `3`. The editor writes version 3 for levels
with eagles, hearts or grenades, version 2 for other decorated levels, and version 1 otherwise.
The game reads all three formats. Metadata and markers occur once each;
object records repeat.

| Record | Fields after the record name |
| --- | --- |
| `name` | Level title, 1–64 UTF-8 bytes |
| `author` | Creator name, 1–48 UTF-8 bytes |
| `biome` | meadow, forest, ridge, night, canyon, halloween, snow, sunset, glacier, blizzard or summit |
| `width` | Integer from 960 to 15360 |
| `spawn` | x, y of Sid's top-left corner (23 × 43 collision box) |
| `goal` | x, y of the finish marker's top-left corner (42 × 92) |
| `checkpoint` | Optional x, y of the checkpoint's top-left corner (18 × 60) |
| `ground` | x, y, width, height of solid terrain |
| `platform` | x, y, width, height of a platform that can be jumped through from below |
| `coin` | x, y of a coin's top-left corner (12 × 16) |
| `ammo` | x, y of an ammo pouch's top-left corner (18 × 22) |
| `heart` | x, y of a heart pickup's top-left corner (20 × 18; version 3) |
| `grenade` | x, y of a grenade pickup's top-left corner (14 × 18; version 3) |
| `monkey` | x, y of a monkey's top-left corner (26 × 28) |
| `bird` | x, y of a bird's top-left corner (28 × 20) |
| `icecube` | x, y of an ice cube's top-left corner (30 × 30) |
| `snowball` | x, y of a snowball's top-left corner (24 × 24) |
| `eagle` | x, y of an eagle's top-left corner (40 × 28; version 3) |
| `decoration` | kind, x, y of the decorative object's top-left corner (versions 2–3) |

Decoration kinds and sizes are `mushroom` (32 × 32), `fern` (32 × 32), `flower` (24 × 32), `crystal` (32 × 48),
`iceflower` (32 × 32), `sparkle` (24 × 24), `sign` (40 × 40), `lantern` (24 × 48), and `banner` (32 × 48).
They have no collision or gameplay effects. Decoration packs control placement in the editor; importing or playing
a decorated level does not require purchasing the packs. Decorations count toward the object limit.

The world is 540 pixels high. Coordinates and dimensions are integers; objects must fit inside its bounds.
Start, finish and checkpoint need a surface at most 96 pixels below their feet. Walking enemies need a surface
directly under their feet, wide enough to contain their entire body. They patrol that surface; birds patrol
120 pixels either side of their initial position, clipped to the map edges. Eagles also patrol up to 120 pixels
either side, start at y=100–280 without needing support, and dive at Sid on the upper route. They have two health
points and require two bullet hits with every fire type. Hearts restore one missing heart; grenades can be carried
one at a time and thrown with G. Combat uses the normal game rules.

Each file may contain at most 2000 objects and be at most 256 KB. Unknown records, duplicate metadata,
invalid UTF-8 and invalid dimensions are rejected. The parser reads records directly and never evaluates Lua.
Filenames created by the game contain only letters, digits, hyphens and underscores, followed by `.sidlevel`.

Use the editor to generate files rather than writing them by hand. The format stores the designed level,
not live enemy positions, collected coins or other temporary state from a test run. Placement validation does
not guarantee that a level is beatable: test every route before sharing it.
