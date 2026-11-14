#!/usr/bin/env python3
import json
import os
import re
import sys
import unicodedata
import urllib.parse
import urllib.request

# Local lyrics library, searched first. Override with the LYRICS_DIR env var.
LOCAL_DIR = os.environ.get("LYRICS_DIR", "/mnt/DriveN/jellyfin/music")

_TS_LINE = re.compile(r"^((?:\[\d+:\d+(?:[.:]\d+)?\])+)(.*)$")
_TS_ONE = re.compile(r"\[(\d+):(\d+(?:[.:]\d+)?)\]")
_WORD_TAG = re.compile(r"<\d+:\d+(?:[.:]\d+)?>")


def _parse_lrc(lrc_text: str) -> list:
    lines = []
    for raw in lrc_text.splitlines():
        m = _TS_LINE.match(raw.strip().lstrip("\ufeff"))
        if not m:
            continue  # metadata tags ([ti:], [ar:], ...) and junk
        text = _WORD_TAG.sub("", m.group(2)).strip()
        for mins, secs in _TS_ONE.findall(m.group(1)):
            try:
                lines.append(
                    {
                        "time": int(mins) * 60 + float(secs.replace(":", ".")),
                        "text": text,
                    }
                )
            except ValueError:
                continue
    return sorted(lines, key=lambda x: x["time"])


def _enough(lines: list) -> bool:
    # a song has more than a line or two; filters junk like "[00:00.00]probe"
    return sum(1 for line in lines if line["text"]) >= 3


# ---------------------------------------------------------------- local ----


def _norm(s: str) -> str:
    s = unicodedata.normalize("NFKC", s).casefold()
    return re.sub(
        r"[\W_]+", "", s
    )  # drops spaces, punctuation and "_" used for illegal filename chars


def _artist_pieces(artist: str) -> list:
    parts = re.split(
        r"\s*(?:,|;|&|/|\bfeat\.?|\bft\.?|\bx\b|\bwith\b)\s*",
        artist,
        flags=re.IGNORECASE,
    )
    pieces = [_norm(p) for p in [artist] + parts]
    return list(dict.fromkeys(p for p in pieces if p))


def _title_score(stem: str, title: str, artist_norms: list) -> int:
    nt = _norm(title) or title.casefold()
    # file stem with and without the leading track number ("01 - ", "07 ", "3. ")
    stripped = re.sub(r"^\d{1,3}(?:[\s.\-_)]+|$)", "", stem)
    best = 0
    for variant in {stem, stripped}:
        ns = _norm(variant)
        if not ns:
            continue
        if ns == nt:
            best = max(best, 3)
        elif ns.endswith(nt) and any(
            ns[: -len(nt)] and (ns[: -len(nt)] in a or a in ns[: -len(nt)])
            for a in artist_norms
        ):
            best = max(best, 3)  # "<artist> - <title>"
        elif nt in ns or ns in nt:
            best = max(best, 1)
    return best


def _candidate_roots(artist_norms: list) -> list:
    try:
        entries = [e for e in os.scandir(LOCAL_DIR) if e.is_dir()]
    except OSError:
        return []
    hits = []
    for e in entries:
        n = _norm(e.name)
        if n and any(n == a or n in a or a in n for a in artist_norms):
            hits.append(e.path)
    return hits


def _scan(root: str, title: str, artist_norms: list, base: str) -> list:
    found = []
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            if not f.lower().endswith(".lrc"):
                continue
            stem = f[:-4]
            score = _title_score(stem, title, artist_norms)
            if not score:
                continue
            rel = _norm(os.path.relpath(os.path.join(dirpath, f), base))
            if not any(a in rel for a in artist_norms):
                continue
            exact_artist = any(
                _norm(os.path.relpath(dirpath, base).split(os.sep)[0]) == a
                for a in artist_norms
            )
            found.append((score, exact_artist, os.path.join(dirpath, f)))
    return found


def _read_text(path: str) -> str:
    with open(path, "rb") as fh:
        raw = fh.read()
    for enc in ("utf-8-sig", "utf-16", "gb18030", "shift_jis", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeError:
            continue
    return raw.decode("utf-8", errors="ignore")


def fetch_local(title: str, artist: str) -> list:
    if not os.path.isdir(LOCAL_DIR):
        return []
    artist_norms = _artist_pieces(artist)
    # fast path: only walk the matching artist folder(s); otherwise whole library
    found = []
    for root in _candidate_roots(artist_norms):
        found += _scan(root, title, artist_norms, LOCAL_DIR)
    if not found:
        found = _scan(LOCAL_DIR, title, artist_norms, LOCAL_DIR)
    for _score, _exact, path in sorted(found, key=lambda x: (-x[0], not x[1], x[2])):
        try:
            lines = _parse_lrc(_read_text(path))
        except OSError:
            continue
        if _enough(lines):
            return lines
    return []


# --------------------------------------------------------------- lrclib ----


def _is_match(d: dict, title: str, artist: str) -> bool:
    if not d.get("syncedLyrics"):
        return False
    r_title = (d.get("trackName") or "").lower()
    r_artist = (d.get("artistName") or "").lower()
    t = title.lower()
    a = artist.lower()
    title_match = (
        t in r_title
        or r_title in t
        or any(word in r_title for word in t.split() if len(word) > 3)
    )
    artist_match = (
        a in r_artist
        or r_artist in a
        or any(word in r_artist for word in a.split() if len(word) > 3)
    )
    return title_match and artist_match


def _usable_lines(d: dict, title: str, artist: str) -> list:
    if not _is_match(d, title, artist):
        return []
    lines = _parse_lrc(d["syncedLyrics"])
    return lines if _enough(lines) else []


def fetch_lrclib(title: str, artist: str, duration: float) -> list:
    urls = [
        f"https://lrclib.net/api/get?track_name={urllib.parse.quote(title)}&artist_name={urllib.parse.quote(artist)}&duration={int(duration)}",
        f"https://lrclib.net/api/search?track_name={urllib.parse.quote(title)}&artist_name={urllib.parse.quote(artist)}",
        f"https://lrclib.net/api/search?q={urllib.parse.quote(title + ' ' + artist)}",
    ]
    for url in urls:
        try:
            with urllib.request.urlopen(url, timeout=15) as r:
                data = json.loads(r.read().decode())
            for d in data if isinstance(data, list) else [data]:
                lines = _usable_lines(d, title, artist)
                if lines:
                    return lines
        except Exception:
            continue
    return []


def main():
    if len(sys.argv) < 4:
        print("no_info", flush=True)
        sys.exit(0)
    title = sys.argv[1]
    artist = sys.argv[2]
    duration = float(sys.argv[3])
    if not title or not artist:
        print("no_info", flush=True)
        sys.exit(0)
    # local files first, lrclib only if nothing usable is found locally
    lines = fetch_local(title, artist) or fetch_lrclib(title, artist, duration)
    if not lines:
        print("not_found", flush=True)
        sys.exit(0)
    parts = []
    for line in lines:
        parts.append(str(line["time"]))
        parts.append(line["text"].replace("§", ""))
    parts.append("ok")
    print("§".join(parts), flush=True)


if __name__ == "__main__":
    main()
