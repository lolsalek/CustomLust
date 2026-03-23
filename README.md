# CustomLust

Shows an animated image overlay and plays a custom sound file whenever a Bloodlust-type buff is applied to your character.

---

## Download

- https://addons.wago.io/addons/customlust

## Features

- Detects all Bloodlust variants automatically — Bloodlust, Heroism, Time Warp, Primal Rage, Drums of Fury, and more
- Plays a fully customisable sound file from your addon's `media` folder
- Displays a customisable animated sprite-sheet image overlay with countdown timer
- Image overlay can be independently enabled or disabled (sound still plays)
- Draggable, resizable overlay with adjustable transparency

---

## Slash Commands

| Command | Description |
|---|---|
| `/customlust` `/cl` | Open or close the options panel |
| `/customlustdump` | Print a debug summary of tracked aura IDs and names, and whether a lust buff is currently active on you |
| `/customlustdumpall` | Print every HELPFUL aura currently on your character — useful for identifying unrecognised lust spell IDs |

---

**Transparency** — Slider controlling overlay opacity from 10% to 100%. Only adjustable while in Edit Mode.

#### Sound File

Configure the audio that plays when lust fires.

- **Path box** — Enter the path to your sound file, relative to the WoW directory. Example: `Interface\AddOns\CustomLust\media\mylust.mp3`
- Accepted formats: `.mp3`, `.ogg`, `.wav`
- **Test Sound** — Saves the current path and plays it immediately so you can audition it without triggering lust
- **Channel** — Dropdown to choose which game audio channel the sound plays through: Master, Music, SFX, Ambience, or Dialog

#### Image File

Configure the overlay image that displays when lust fires.

- **Enable image overlay** — Checkbox to show or hide the image. When unchecked the sound still plays but no image is shown
- **Path box** — Enter the path to your image file, relative to the WoW directory. Example: `Interface\AddOns\CustomLust\media\myimage.tga`
- Accepted formats: `.tga`, `.blp`, `.png`
- **Thumbnail** — Live preview of the selected image shown to the right of the path box
- **Apply Image** — Saves the current path and hot-reloads the overlay texture immediately
- **Reset Default** — Reverts the image path back to the addon's bundled default

---

## Media Folder

Place your custom sound and image files inside the addon's `media` folder:

```
Interface/
  AddOns/
    CustomLust/
      media/
        mysound.mp3
        myimage.tga
      CustomLust.lua
      CustomLust_Options.lua
      CustomLust.toc
```

Then enter the path in the options panel as `Interface\AddOns\CustomLust\media\mysound.mp3`.

## Troubleshooting

**The overlay doesn't appear when lust fires**
1. Make sure **Enable CustomLust** is checked in the options panel
2. Make sure **Enable image overlay** is checked if you want the visual
3. Pop Time Warp or another lust buff and run `/customlustdump` — it will tell you whether the buff was detected
4. If the buff isn't detected, run `/customlustdumpall` while the buff is active and check whether the spell appears in the list. If it does, report the spell ID so it can be added to the default list

**The sound doesn't play**
1. Check that the path in the Sound File box points to a real file in the correct format (`.mp3`, `.ogg`, or `.wav`)
2. Use the **Test Sound** button to verify the file plays outside of a lust event
3. Make sure the selected audio Channel is not muted in the WoW sound settings

**The image path was entered but looks wrong**
- Use backslashes (`\`) as path separators, not forward slashes
- The path must start with `Interface\`, not a drive letter or absolute path
- The panel will normalise forward slashes to backslashes automatically on save
