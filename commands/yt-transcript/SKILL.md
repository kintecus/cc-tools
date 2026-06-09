---
name: yt-transcript
description: >
  Fetch, search, quote, and summarize a YouTube video by its caption track.
  Plain web search cannot see spoken content; this pulls the captions (not the
  video) via yt-dlp and greps the text. Use PROACTIVELY whenever a question
  hinges on what was SAID in a specific YouTube video and the answer is not in
  search results or articles. Triggers: "what did X say in this video", "find
  the quote in this talk/podcast/interview", "search this YouTube video",
  "grep this video", "transcript of this video", "where in the video does he
  say", "summarize this YouTube video", "did they mention X in the video",
  "timestamp for when they talk about X", "yt-transcript". Also use to verify a
  claim attributed to a video when text search comes up empty.
---

# yt-transcript

Search and quote YouTube videos by their caption track. The bundled
`yt-transcript` script downloads only the captions (not the video), cleans them
into readable plain text, and you grep/awk from there.

This exists because **plain web search and WebFetch cannot read spoken content.**
Auto-caption tracks are not web-indexed, and YouTube watch pages load the
transcript via JS (and often 403 automated fetches). So when a user asks what
was said in a video, search will find the video but not the line. This skill is
the reliable path.

## When to use it

- A user asks what someone **said** in a specific YouTube video, or to find a
  quote / verify a claim attributed to one.
- A user wants a video **searched, quoted, summarized**, or a timestamp for a
  topic.
- Text search found the video but not the spoken passage (the dead giveaway
  that you need captions, not search).

Use it proactively the moment a question depends on in-video speech and you have
(or can find) the URL. Do not use it for video metadata (title, views, channel)
that ordinary search already answers.

## Requirements

- `yt-dlp` installed: `brew install yt-dlp`
- Optional `deno` helps yt-dlp solve YouTube's JS challenges. yt-dlp prints a
  warning when it is missing but usually still works.

## How to use

The script lives next to this file. Invoke it by absolute path (it is not on
`PATH`):

```bash
SCRIPT="${CLAUDE_PLUGIN_ROOT:-$HOME/code/cc-tools}/commands/yt-transcript/yt-transcript"
```

### 1. Find a quote / verify a claim (most common)

Pipe the cleaned transcript to grep. Accepts a full URL or a bare 11-char ID.

```bash
"$SCRIPT" "https://www.youtube.com/watch?v=VIDEO_ID" | grep -n -i "kubernetes"
```

`grep -n` gives line numbers into the cleaned text. To read the surrounding
context, dump to a file first (next step) and `awk` a line window.

### 2. Full transcript dump (for reading or deeper work)

```bash
"$SCRIPT" "VIDEO_ID" -o /tmp/transcript.txt
```

Then pull context around a hit:

```bash
grep -n -i "PHRASE" /tmp/transcript.txt          # find the line number, say 140
awk 'NR>=130 && NR<=160' /tmp/transcript.txt     # read the window around it
```

### 3. Summarize the video

Dump the transcript to a file, read it, and summarize. For long videos
(1h+ transcripts can be large), summarize in sections rather than loading the
whole thing at once.

```bash
"$SCRIPT" "VIDEO_ID" -o /tmp/transcript.txt
wc -l /tmp/transcript.txt    # gauge length before reading
```

### 4. Timestamp / jump link for a topic

Use `--raw` to keep SRT timestamps, find the cue, and build a `&t=` deep link.

```bash
"$SCRIPT" "VIDEO_ID" --raw -o /tmp/transcript.srt
grep -n -B2 -i "PHRASE" /tmp/transcript.srt      # shows the HH:MM:SS,mmm --> cue above the line
```

Convert the start timestamp `HH:MM:SS` to seconds and append
`&t=<seconds>s` to the watch URL for a jump link.

## Caption source and accuracy

The script prefers **manual (human-authored) captions** for accuracy and falls
back to **auto-generated** ones. When it uses auto-generated captions it prints
a warning to stderr:

```
yt-transcript: using AUTO-GENERATED captions — text is imperfect, verify exact wording before quoting.
```

Heed it. Auto-captions get the gist right but mangle punctuation, occasionally
repeat a word ("up up in up in"), and lack speaker labels. **When quoting from
auto-captions, lightly normalize obvious artifacts and tell the user the wording
is from auto-generated captions** so they know it is approximate, not verbatim.

If neither track exists, the script exits non-zero with a clear message (e.g.
no captions in the requested language, private/members-only video). Relay that
to the user rather than guessing at content. Try `--lang <code>` for a different
caption language before giving up.

## Options

| Flag | Effect |
|---|---|
| `-o, --out FILE` | Also write the (cleaned or raw) transcript to FILE |
| `--lang LANG` | Caption language code, default `en` |
| `--raw` | Keep SRT timestamps; skip the cleaning/dedup pass |
| `--keep` | Keep the intermediate `.srt` working file |
| `-h, --help` | Usage |

## Notes

- The cleaning pass strips SRT index/timestamp lines and dedupes YouTube's
  rolling 3x-repeated caption lines, so the output is readable prose-ish text.
- Only the caption track is downloaded (a few hundred KB), never the video.
- Works on any YouTube URL form (`watch?v=`, `youtu.be/`, `shorts/`) and on a
  bare 11-character video ID.
