# /// script
# requires-python = ">=3.10"
# dependencies = ["manifold3d==3.2.1", "svgelements==1.9.6", "numpy"]
# ///
"""Geometry backend for inlay-stl. Run via `uv run --script`; reads a JSON job on stdin.

Builds a filleted baseplate in the background color, cuts a pocket `depth` deep
for every non-background color region in the SVG (as written by inlay-svg),
and writes one STL per color. All STLs share one coordinate system, so a slicer
loading them together as parts of one object gets a flush multi-color inlay.

SVG contract: top-level <g data-color=... data-name=... data-role=background|inlay>,
background group first. Later groups win where shapes overlap.
"""
import json
import math
import struct
import sys

import manifold3d as m
import numpy as np
from svgelements import SVG, Group, Path, Move, Close, Line


def fail(msg):
    print(json.dumps({"error": msg}))
    sys.exit(1)


def flatten_path(path, tol):
    """Path -> list of closed polylines (lists of (x, y)), curves sampled every ~tol mm."""
    polys, cur = [], []
    for seg in path:
        if isinstance(seg, Move):
            if len(cur) > 2:
                polys.append(cur)
            cur = [(seg.end.x, seg.end.y)]
        elif isinstance(seg, Close):
            if len(cur) > 2:
                polys.append(cur)
            cur = []
        elif isinstance(seg, Line):
            cur.append((seg.end.x, seg.end.y))
        elif seg.start is not None:
            n = max(2, min(64, math.ceil(seg.length(error=1e-3) / tol)))
            for i in range(1, n + 1):
                p = seg.point(i / n)
                cur.append((p.x, p.y))
    if len(cur) > 2:
        polys.append(cur)
    return polys


def load_groups(svg_path, tol):
    # ppi=25.4 makes one user unit == one millimetre
    svg = SVG.parse(svg_path, ppi=25.4, reify=True)
    groups = []
    for el in svg:
        if not isinstance(el, Group) or "data-color" not in el.values:
            continue
        polys = []
        for p in el.select(lambda e: isinstance(e, Path)):
            polys += flatten_path(p, tol)
        groups.append({
            "color": el.values["data-color"],
            "name": el.values.get("data-name", el.values["data-color"]),
            "role": el.values.get("data-role", "inlay"),
            "polys": polys,
        })
    if not groups:
        fail(f"no <g data-color=...> groups found in {svg_path}; was it made by inlay-svg?")
    return groups, float(svg.width), float(svg.height)


def write_stl(manifold, path):
    mesh = manifold.to_mesh()
    v = np.asarray(mesh.vert_properties)[:, :3].astype(np.float64)
    t = np.asarray(mesh.tri_verts)
    a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
    n = np.cross(b - a, c - a)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    rec = np.zeros(len(t), dtype=[("n", "<f4", 3), ("v", "<f4", (3, 3)), ("attr", "<u2")])
    rec["n"], rec["v"] = n, np.stack([a, b, c], axis=1)
    with open(path, "wb") as f:
        f.write(b"inlay-stl".ljust(80, b" "))
        f.write(struct.pack("<I", len(t)))
        f.write(rec.tobytes())
    return len(t)


def main():
    job = json.load(sys.stdin)
    groups, art_w, art_h = load_groups(job["svg"], job["tolerance"])
    W, H, T, D = job["width"], job["height"], job["thickness"], job["depth"]
    r, margin = job["fillet"], job["margin"]
    if D >= T:
        fail(f"depth {D} must be less than thickness {T}")
    if r * 2 > min(W, H):
        fail(f"fillet {r} is too big for a {W}x{H} plate")

    # Art placement: scale to fit inside margin (unless no_scale), centred, y flipped.
    s = 1.0 if job["no_scale"] else min((W - 2 * margin) / art_w, (H - 2 * margin) / art_h)
    ox, oy = (W - art_w * s) / 2, (H - art_h * s) / 2

    def section(polys):
        pts = [[(ox + x * s, oy + (art_h - y) * s) for x, y in poly] for poly in polys]
        return m.CrossSection(pts, m.FillRule.EvenOdd) if pts else m.CrossSection()

    outline = m.CrossSection.square((W, H))
    if r > 0:
        outline = outline.offset(-r, m.JoinType.Round, circular_segments=64).offset(
            r, m.JoinType.Round, circular_segments=64)

    # Later groups win overlaps: walk backwards, subtracting what's already claimed.
    inlays = [g for g in groups if g["role"] != "background"]
    claimed = m.CrossSection()
    w = job["min_width"] / 2
    for g in reversed(inlays):
        region = (section(g["polys"]) - claimed) ^ outline
        if w > 0:  # morphological opening drops slivers thinner than min_width
            region = region.offset(-w, m.JoinType.Round).offset(w, m.JoinType.Round) ^ outline
        claimed = claimed + region
        g["region"] = region

    plate = m.Manifold.extrude(outline, T) - m.Manifold.extrude(claimed, D + 1).translate((0, 0, T - D))
    background = next((g for g in groups if g["role"] == "background"), {"name": "background", "color": "#ffffff"})

    results = []
    parts = [(background, plate)] + [
        (g, m.Manifold.extrude(g["region"], D).translate((0, 0, T - D))) for g in inlays]
    for i, (g, solid) in enumerate(parts, start=1):
        if solid.is_empty():
            results.append({"name": g["name"], "color": g["color"], "skipped": "empty after cleanup"})
            continue
        slug = "".join(ch if ch.isalnum() else "-" for ch in g["name"]).strip("-").lower() or "color"
        path = f"{job['prefix']}-{i:02d}-{slug}.stl"
        tris = write_stl(solid, path)
        results.append({"name": g["name"], "color": g["color"], "path": path,
                        "triangles": tris, "volume_mm3": round(solid.volume(), 1)})
    print(json.dumps({"scale": s, "art_mm": [round(art_w * s, 2), round(art_h * s, 2)],
                      "parts": results}))


if __name__ == "__main__":
    main()
