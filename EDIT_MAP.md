# EDIT_MAP.md

> Read first, every session. Every cut, asset and render traces back to this
> file. Replace each `<...>` with something true about *this* project. Source
> footage listed here is read-only: the kit never edits, moves or overwrites it.

## Project
- **What this is, in one line:** <e.g. 40-minute podcast episode → three 45-second shorts>
- **Owner:** <who approves cuts and renders>
- **Brief:** <path to video-brief.md, or "none">

## Source footage
<!-- Read-only. Record what ffprobe reports, not what the file name says. -->
| File | Duration | Resolution / fps | Audio | Notes |
|---|---|---|---|---|
| <footage/ep12.mp4> | <00:41:20> | <3840x2160 / 29.97> | <stereo, 48 kHz> | <two cameras, host left> |

## Style
- **Pace:** <e.g. cut every 2–4 s; no jump cuts mid-sentence>
- **Captions:** <font, size, position, max words per line, burned in or sidecar>
- **Look:** <colour, brand elements, intro/outro or none>
- **Never:** <e.g. zoom punch-ins, stock transitions, emoji captions>

## Delivery
<!-- One row per output. A render is checked against its row: frame samples, ffprobe and a loudness measurement. -->
| Target | Resolution | fps | Codec / container | Loudness | Safe zone |
|---|---|---|---|---|---|
| <Shorts / Reels> | <1080x1920> | <30> | <H.264 + AAC / mp4> | <-14 LUFS, -1 dBTP> | <keep text out of the bottom 20% and top 10%> |

## Assets
<!-- Music, fonts, stock clips, logos, SFX. An asset without a licence row never enters a render. -->
| Asset | Source | Licence | Attribution needed | Checked |
|---|---|---|---|---|
| <music/bed.mp3> | <site or author> | <licence name + link> | <yes: "..." / no> | <date> |

## Evidence
<!-- Every number or claim shown on screen or in subtitles needs a row. No row → [NEEDS PROOF]. -->
| Claim | Source | Checked |
|---|---|---|
| <e.g. "3x faster builds"> | <benchmark link, timestamp in footage> | <date> |

## Learnings
<!-- What a cut or render taught you, with the number that showed it. -->
- <date>: <what was tried> → <result> → <what changes next time>
