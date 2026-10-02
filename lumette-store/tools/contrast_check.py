#!/usr/bin/env python3
"""WCAG 2.1 contrast checker for the Lumette palette. Exit code 1 if any pair fails."""
import sys

PALETTE = {
    "bg": "#FBF7F2", "surface": "#F4E9E1", "blush": "#F2D9D2", "ink": "#2A2220",
    "ink_soft": "#5B4D47", "accent": "#8F3A4B", "accent_hover": "#742E3C",
    "sage": "#3F5C4D", "white": "#FFFFFF", "line": "#E6D8CE", "error": "#A3262E",
}
# (foreground, background, minimum ratio, what it is)
PAIRS = [
    ("ink", "bg", 4.5, "body text"),
    ("ink", "surface", 4.5, "body text on sand panels"),
    ("ink", "blush", 4.5, "body text on blush"),
    ("ink_soft", "bg", 4.5, "secondary text"),
    ("ink_soft", "surface", 4.5, "secondary text on sand"),
    ("white", "accent", 4.5, "primary button label"),
    ("white", "accent_hover", 4.5, "primary button hover"),
    ("accent", "bg", 4.5, "links / accent text on cream"),
    ("white", "sage", 4.5, "success badge / sage labels"),
    ("sage", "bg", 4.5, "free-shipping text"),
    ("error", "bg", 4.5, "form errors"),
    ("white", "ink", 4.5, "dark footer/announcement text"),
    ("accent", "white", 4.5, "accent on white (cart drawer)"),
    ("line", "bg", 1.0, "decorative borders (no minimum)"),
    ("accent", "bg", 3.0, "focus ring (non-text, 3:1)"),
]

def lum(h):
    h = h.lstrip("#")
    r, g, b = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

bad = 0
for fg, bg, mn, what in PAIRS:
    r = ratio(PALETTE[fg], PALETTE[bg])
    ok = r >= mn
    bad += not ok
    print(f"{'PASS' if ok else 'FAIL'}  {r:5.2f}:1 (min {mn})  {fg} on {bg}  - {what}")
sys.exit(1 if bad else 0)
