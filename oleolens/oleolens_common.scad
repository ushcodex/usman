// ============================================================================
// OleoLens  |  oleolens_common.scad
// Shared drafting + modelling helpers. Do not render this file directly.
// Used by oleolens_handheld.scad and oleolens_clip.scad (via include).
// ============================================================================

// ---------- palette ----------
C_SHELL = "#2d3139";   // charcoal polymer
C_TEAL  = "#14a9b8";   // OleoLens teal (TPU / accents)
C_PCB   = "#1b6b3a";
C_GOLD  = "#d4af37";
C_BLACK = "#14161a";
C_FLUID = "#c45a00";
C_CLEAR = [0.75, 0.9, 1.0, 0.35];
C_DIM   = "#d01818";

// ============================================================================
// 3D MODELLING HELPERS
// ============================================================================

// Rounded box with different top/bottom edge radii. Spans x0..x1, centred on y.
// inset > 0 shrinks the solid uniformly (used to make shell walls); < 0 grows it.
module rbox(x0, x1, w, h, rv, rt, rb = 2, inset = 0) {
    i   = inset;
    rvi = max(rv - i, 1);
    rti = max(min(rt - i, rvi / 2 - 0.3), 0.4);
    rbi = max(min(rb - i, rvi / 2 - 0.3), 0.4);
    xa  = x0 + i;
    xb  = x1 - i;
    wy  = (w - 2 * i) / 2;
    hull() {
        for (sx = [xa + rvi, xb - rvi], sy = [-(wy - rvi), (wy - rvi)]) {
            translate([sx, sy, i + rbi])
                rotate_extrude($fn = 36) translate([rvi - rbi, 0]) circle(rbi, $fn = 16);
            translate([sx, sy, h - i - rti])
                rotate_extrude($fn = 36) translate([rvi - rti, 0]) circle(rti, $fn = 16);
        }
    }
}

// Orient children so their +Z axis points along vector v
module orient(v) {
    L = norm(v);
    rotate([0, acos(v[2] / L), atan2(v[1], v[0])]) children();
}

module rod(a, b, d = 0.5) {
    v = b - a;
    if (norm(v) > 0.01) translate(a) orient(v) cylinder(d = d, h = norm(v), $fn = 8);
}

// PCB slab with corner at its centre-x/y, bottom at z=0
module pcb(l, w, t = 1.6, c = C_PCB) {
    color(c) translate([-l / 2, -w / 2, 0]) cube([l, w, t]);
}

// Round-ended cutter along X (for slots / USB-C)
module slot_x(len, w, h) {
    hull() for (s = [-1, 1])
        translate([0, s * (w / 2 - h / 2), 0]) rotate([0, 90, 0])
            cylinder(d = h, h = len, center = true, $fn = 24);
}

// ---------- 3D dimension + label annotations ----------
// face = "y": text faces -Y viewer.  face = "x": text faces -X viewer.
module dim3(p1, p2, off, t, ts = 4, face = "y") {
    a = p1 + off;
    b = p2 + off;
    n = off / norm(off);
    color(C_DIM) {
        rod(a, b, 0.5);
        rod(p1 + n * 1.5, a + n * 2, 0.3);
        rod(p2 + n * 1.5, b + n * 2, 0.3);
        translate(a) orient(b - a) cylinder(d1 = 0, d2 = 2, h = 4, $fn = 12);
        translate(b) orient(a - b) cylinder(d1 = 0, d2 = 2, h = 4, $fn = 12);
        translate((a + b) / 2 + [0, 0, 2.2])
            rotate(face == "y" ? [90, 0, 0] : [90, 0, -90])
                linear_extrude(0.5) text(t, size = ts, halign = "center", valign = "baseline");
    }
}

module label3(txt, tip, pos, ts = 3.6) {
    color("#0a4a8a") {
        rod(tip, pos, 0.35);
        translate(tip) sphere(d = 1.4, $fn = 10);
        translate(pos + [0, 0, 1]) rotate([90, 0, 0])
            linear_extrude(0.5) text(txt, size = ts, halign = "left", valign = "baseline");
    }
}

// ============================================================================
// 2D DRAFTING HELPERS (for export to SVG / DXF)
// ============================================================================
module line2(p1, p2, w = 0.25) {
    hull() { translate(p1) circle(d = w, $fn = 8); translate(p2) circle(d = w, $fn = 8); }
}

module arrow2(p, ang, s = 2.6) {
    translate(p) rotate(ang) polygon([[0, 0], [-s, s * 0.18], [-s, -s * 0.18]]);
}

module txt(t, size = 3, ha = "center", va = "center") {
    text(str(t), size = size, halign = ha, valign = va);
}

module ring2(d, w = 0.3) { difference() { circle(d = d, $fn = 48); circle(d = d - 2 * w, $fn = 48); } }

module rect_outline(x, y, w, h, t = 0.3) {
    difference() {
        translate([x, y]) square([w, h]);
        translate([x + t, y + t]) square([w - 2 * t, h - 2 * t]);
    }
}

// Outline of any 2D shape (use for hidden/internal parts and wireframe views)
module outline2(w = 0.3) {
    difference() { offset(delta = w / 2) children(); offset(delta = -w / 2) children(); }
}

// Horizontal dimension: x1..x2 measured, drawn at height y, object edges at yo1/yo2
module dim_h(x1, x2, y, yo1, yo2, t = undef, ts = 3) {
    xa = min(x1, x2); xb = max(x1, x2);
    s1 = (y >= yo1) ? 1 : -1;
    s2 = (y >= yo2) ? 1 : -1;
    line2([x1, yo1 + s1 * 1], [x1, y + s1 * 1.5], 0.2);
    line2([x2, yo2 + s2 * 1], [x2, y + s2 * 1.5], 0.2);
    line2([xa, y], [xb, y], 0.25);
    arrow2([xa, y], 180);
    arrow2([xb, y], 0);
    translate([(xa + xb) / 2, y + 2.2])
        txt(is_undef(t) ? str(round((xb - xa) * 10) / 10) : t, ts, "center", "baseline");
}

// Vertical dimension
module dim_v(y1, y2, x, xo1, xo2, t = undef, ts = 3) {
    ya = min(y1, y2); yb = max(y1, y2);
    s1 = (x >= xo1) ? 1 : -1;
    s2 = (x >= xo2) ? 1 : -1;
    line2([xo1 + s1 * 1, y1], [x + s1 * 1.5, y1], 0.2);
    line2([xo2 + s2 * 1, y2], [x + s2 * 1.5, y2], 0.2);
    line2([x, ya], [x, yb], 0.25);
    arrow2([x, ya], -90);
    arrow2([x, yb], 90);
    translate([x - 1.4, (ya + yb) / 2]) rotate(90)
        txt(is_undef(t) ? str(round((yb - ya) * 10) / 10) : t, ts, "center", "baseline");
}

// Diameter callout
module dim_dia(c, d, ang, t = undef, ts = 3) {
    p1 = c + (d / 2) * [cos(ang), sin(ang)];
    p2 = c + (d / 2 + 9) * [cos(ang), sin(ang)];
    line2(c - (d / 2) * [cos(ang), sin(ang)], p2, 0.2);
    arrow2(p1, ang + 180);
    translate(p2 + [cos(ang) >= 0 ? 1 : -1, 0] * 1.5)
        txt(is_undef(t) ? str("DIA ", d) : t, ts, cos(ang) >= 0 ? "left" : "right", "center");
}

// Part balloon with leader
module balloon(n, tip, pos) {
    difference() { line2(tip, pos, 0.25); translate(pos) circle(d = 7, $fn = 40); }
    translate(tip) circle(d = 1.1, $fn = 12);
    translate(pos) { ring2(7); txt(n, 3.2); }
}

// Section hatch: fills children with 45 degree lines
module hatch2(sp = 2.2, span = 300) {
    intersection() {
        children();
        union() for (k = [-span : sp : span]) line2([k, -span], [k + 2 * span, span], 0.22);
    }
}

// Centre-line cross
module centre2(p, l = 6) { line2(p - [l, 0], p + [l, 0], 0.12); line2(p - [0, l], p + [0, l], 0.12); }

// View caption (e.g. "PLAN VIEW  SCALE 1:1")
module caption(t, p, sc) {
    translate(p) { txt(t, 4.2, "center", "center"); translate([0, -5]) txt(str("SCALE ", sc), 2.6, "center", "center"); }
}

// A3 sheet frame + title block
module sheet_frame(W = 420, H = 297, m = 10) {
    rect_outline(0, 0, W, H, 0.2);
    rect_outline(m, m, W - 2 * m, H - 2 * m, 0.7);
    // zone ticks along top and bottom
    for (i = [1 : 5]) {
        x = m + (W - 2 * m) * (i - 0.5) / 5;
        translate([x, H - m / 2]) txt(i, 2.6);
        translate([x, m / 2])     txt(i, 2.6);
    }
    for (i = [0 : 5]) {
        x = m + (W - 2 * m) * i / 5;
        line2([x, H - m], [x, H - m + 2.5], 0.2); line2([x, m], [x, m - 2.5], 0.2);
    }
    for (i = [1 : 4]) {
        y = m + (H - 2 * m) * (i - 0.5) / 4;
        translate([m / 2, y]) txt(chr(64 + 5 - i), 2.6);
        translate([W - m / 2, y]) txt(chr(64 + 5 - i), 2.6);
    }
}

module title_block(title, subtitle, dwg_no, scale_txt, mass_txt, drawn_by = "USMAN", W = 420, m = 10) {
    bx = W - m - 180; by = m; bw = 180; bh = 42; rh = bh / 4;
    rect_outline(bx, by, bw, bh, 0.5);
    // left block: name / date rows
    line2([bx + 74, by], [bx + 74, by + bh], 0.35);
    for (r = [1 : 3]) line2([bx, by + r * rh], [bx + 74, by + r * rh], 0.25);
    line2([bx + 30, by + rh], [bx + 30, by + bh], 0.25);
    translate([bx + 2, by + 3 * rh + 1.5])  txt("NAME", 2, "left", "bottom");
    translate([bx + 32, by + 3 * rh + 1.5]) txt("DATE", 2, "left", "bottom");
    translate([bx + 2, by + 2 * rh + 1.5])  txt("DRAWN", 2.4, "left", "bottom");
    translate([bx + 32, by + 2 * rh + 1.5]) txt(drawn_by, 2.8, "left", "bottom");
    translate([bx + 2, by + rh + 1.5])      txt("CHECKED", 2.4, "left", "bottom");
    translate([bx + 2, by + 1.5])           txt("APPROVED", 2.4, "left", "bottom");
    // right block: four rows
    for (r = [1 : 3]) line2([bx + 74, by + r * rh], [bx + bw, by + r * rh], 0.25);
    line2([bx + 120, by], [bx + 120, by + rh], 0.25);
    line2([bx + 150, by], [bx + 150, by + rh], 0.25);
    line2([bx + 150, by + rh], [bx + 150, by + 2 * rh], 0.25);
    translate([bx + 77, by + 3.5 * rh]) txt(str("OLEOLENS | ", title), 3.2, "left", "center");
    translate([bx + 77, by + 2.5 * rh]) txt(subtitle, 2.6, "left", "center");
    translate([bx + 77, by + 1.5 * rh]) txt(str("DWG NO. ", dwg_no), 3, "left", "center");
    translate([bx + 152, by + 1.5 * rh]) txt("REV A", 2.6, "left", "center");
    translate([bx + 77, by + 0.5 * rh]) txt("SIZE A3", 2.6, "left", "center");
    translate([bx + 122, by + 0.5 * rh]) txt(str("SCALE ", scale_txt), 2.6, "left", "center");
    translate([bx + 152, by + 0.5 * rh]) txt(mass_txt, 2.6, "left", "center");
}

// Parts list table: rows = [[no, description, qty], ...]; (x,y) = top-left
module part_list(x, y, rows, w = 108, rh = 6.2) {
    n = len(rows) + 1;
    rect_outline(x, y - n * rh, w, n * rh, 0.4);
    line2([x + 12, y], [x + 12, y - n * rh], 0.25);
    line2([x + w - 12, y], [x + w - 12, y - n * rh], 0.25);
    for (r = [1 : n - 1]) line2([x, y - r * rh], [x + w, y - r * rh], 0.2);
    translate([x + 6, y - rh / 2]) txt("ITEM", 2.4, "center", "center");
    translate([x + 15, y - rh / 2]) txt("DESCRIPTION", 2.4, "left", "center");
    translate([x + w - 6, y - rh / 2]) txt("QTY", 2.4, "center", "center");
    for (r = [0 : len(rows) - 1]) {
        yy = y - (r + 1.5) * rh;
        translate([x + 6, yy]) txt(rows[r][0], 2.5, "center", "center");
        translate([x + 15, yy]) txt(rows[r][1], 2.3, "left", "center");
        translate([x + w - 6, yy]) txt(rows[r][2], 2.5, "center", "center");
    }
}

// Multi-line notes block; lines = ["...", ...]
module notes_block(x, y, lines, ts = 2.3, lh = 4) {
    translate([x, y]) txt("NOTES", 2.8, "left", "baseline");
    for (i = [0 : len(lines) - 1])
        translate([x, y - (i + 1) * lh]) txt(lines[i], ts, "left", "baseline");
}
