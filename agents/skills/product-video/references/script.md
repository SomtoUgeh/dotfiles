# Scene script

Each video is one data file: `video/src/script/<id>.ts`. The edit and the voice tool
read the same file. Keep it data-only: type imports are allowed, runtime imports are not.

Register each script in `video/src/script/index.ts`. The key, the script `id` and the
file name must be equal. The key is also the composition id.

## Scene kinds

```ts
{ id: "intro", kind: "intro", title: "Set up in one minute", subtitle: "…", voice: "…" }
{ id: "chapter-signup", kind: "chapter", eyebrow: "Step one", title: "Create a workspace", voice: "…" }
{ id: "signup", kind: "app", clip: "example-01-signup", from: "form", to: "submit",
  caption: "Three fields", voice: "…" }
{ id: "outro", kind: "outro", tagline: "Start your workspace today.", url: "app.example.com", voice: "…" }
```

Fields of an `app` scene:

| Field | Meaning |
| --- | --- |
| `clip` | Clip name: `public/clips/<clip>.mp4` and `.json`. |
| `from` | Start of the footage: a beat id, or seconds. |
| `to` | End of the footage: a beat id, `"end"`, or seconds. Default: the next beat after `from`. |
| `caption` | Two to four words on screen that interpret the scene. |
| `eyebrow` | Optional small label above the caption. |
| `zoom` | `"auto"` (default), `"off"`, or `{ region: { x, y, width, height }, zoom? }` in CSS pixels of the recorded viewport. |
| `holdSeconds` | How long the last frame stays after the footage ends. Default 0.8. |
| `minSeconds` | Minimum scene length. Default 4 for `app`, 4.5 for `intro`, 3.4 for `chapter`, 5 for `outro`. |
| `captionPlacement` | `"auto"` (default), `"bottom-left"`, `"bottom-right"`. |
| `keepNavigation` | Keep a page change that occurs in the last 1.2 s. Default: the scene stops before it. |

The full type is in `video/src/script/types.ts`.

## How long a scene is

Scene length is the largest of:

- the minimum for its kind,
- voice lead-in 0.55 s + narration + tail 0.7 s,
- footage length + hold.

Footage plays at recorded speed. If the narration is longer than the footage, the last
frame freezes. If the footage is longer than the narration, the scene has silence. Both
are faults when they are long. The timeline report finds them (see [edit.md](edit.md)).

## Write the narration

1. Print the footage length between beats: `npm run beats`.
2. Write one complete paragraph for each scene. Size it at about 2.4 words for each
   second of footage.
3. Describe what is on the screen at that moment. Name the person and the data that the
   viewer sees.
4. Each passage must be complete on its own. Do not end a passage in the middle of a
   thought, and do not start one with "And" or "Then it".
5. Write numbers as words when the voice must read them ("seven Chapel Street").
6. Put a product name with an unusual spelling early in the passage. A name near the end
   of a long passage is mispronounced most often.
7. Use `intro` and `chapter` cards to say what comes next. They also give the viewer a
   rest between long app scenes.

A scene with no `voice` is silent and uses its minimum length or its footage length.

## Cut points

- A scene with no `to` stops at the next beat, even if that beat is 2 seconds later.
  Set `to` to a later beat or to `"end"` when the narration covers more footage.
- Two scenes can share a range boundary (`to` of one equals `from` of the next). They
  must not overlap.
- A beat is logged when the tour calls it. This can be after the screen changed. To cut
  at the visible change, find its time and use seconds:

  ```sh
  ffmpeg -hide_banner -i public/clips/<clip>.mp4 \
    -vf "select='gt(scene,0.02)',showinfo" -f null - 2>&1 | grep -o "pts_time:[0-9.]*"
  ```

  Lower the threshold when the two screens look alike. Raise it when it reports motion
  inside one screen.

## Fixed zoom regions

Use a fixed region when the automatic camera has no click to follow, for example on a
report page:

```ts
zoom: { region: { x: 960, y: 240, width: 440, height: 560 } }
```

The numbers are CSS pixels in the 1440×900 viewport. Read them from a contact sheet of
the clip, or from the `box` of a nearby event in the clip JSON.
