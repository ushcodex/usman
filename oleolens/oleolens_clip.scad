// ============================================================================
// OleoLens CLIP  (Tier 2: smartphone attachment)
// Spring-clamp bridge + optical head that sits over the phone's rear camera.
// Phone camera does the imaging through a clip-on macro lens. The head carries
// LEDs (446 nm / UVC 269 nm / white / green), SiC UV photodiode, ESP32-C3 (BLE)
// and a small LiPo. Same 24 x 50 x 6 cartridge as the handheld.
//
// HOW TO USE
//   1. Keep oleolens_common.scad in the same folder.
//   2. Pick a view in the Customizer, F5 to preview.
//   3. Drawing sheets: view = sheet_ga or sheet_section, F6, then
//      File > Export > SVG or DXF.
//   Units: mm. Origin = centre of the phone's main rear lens. Phone back face
//   is the plane Z=0 (phone body is below, Z<0). +X = tray side.
// ============================================================================
include <oleolens_common.scad>

/* [View] */
view = "assembly";      // [assembly, exploded, internals, tray_open, sheet_ga, sheet_section]
tray_out = 0;
show_phone = true;      // translucent reference phone
show_dims = true;
cutaway = false;
x_adj = 0;              // slide the head along the bridge (alignment demo), +/-4

/* [Phone being clamped] */
PHONE_W = 72;           // 64..80 supported by the jaws
PHONE_L = 150;
PHONE_T = 8.6;
CAM_FROM_LEFT = 22;     // camera centre to left edge (X)
CAM_FROM_TOP  = 22;     // camera centre to top edge (Y)

/* [Head] */
HW = 64;  HD = 46;      // head X and Y size
Z0 = 3.4;  ZTOP = 43;   // head base and top
WALL = 2.2;  SPLIT = 26;
CELL_PATH = 2.0;

$fn = 36;
XL = -CAM_FROM_LEFT;            // left phone edge
XR = XL + PHONE_W;              // right phone edge
X_BRK = 88;                     // fixed spring bracket
TRAY = (view == "tray_open") ? 40 : tray_out;
function ex(k) = (view == "exploded") ? k : 0;

// -------------------------------------------------------------- phone -------
module phone() {
    color([0.25, 0.27, 0.32, 0.35]) {
        translate([0, -(PHONE_L / 2 - CAM_FROM_TOP), -PHONE_T]) rbox(XL, XR, PHONE_L, PHONE_T, 10, 4, 2);
        translate([-18, -18, 0]) cube([36, 36, 1.5]);                         // camera island
    }
    color("#111") {
        translate([0, 0, 1.5]) cylinder(d = 10, h = 0.6);                     // main lens
        translate([0, -13, 1.5]) cylinder(d = 8, h = 0.5);
        translate([0, 13, 1.5]) cylinder(d = 6, h = 0.4);
    }
}

// ------------------------------------------------------------ clamp ---------
module bridge() {
    color(C_SHELL) translate([0, 0, 0.4]) linear_extrude(3) difference() {
        translate([XL - 5, -27]) offset(r = 4) offset(delta = -4) square([X_BRK + 6 - (XL - 5), 54]);
        translate([-22, -20]) square([44, 40]);                                  // island + travel relief
    }
    // fixed left jaw
    color(C_SHELL) translate([XL - 5, -22, -PHONE_T - 2]) cube([2.4, 44, PHONE_T + 2 + 3.8]);
    color(C_TEAL) translate([XL - 2.6, -22, -PHONE_T - 2]) cube([4.6, 44, 1.8]);          // TPU lip
    color(C_TEAL) translate([XL - 0.2, -20, -PHONE_T]) cube([0.2, 40, PHONE_T]);          // TPU liner
    // spring bracket (fixed)
    color(C_SHELL) translate([X_BRK, -27, 3.4]) cube([6, 54, 6]);
}
module sliding_jaw() {
    color(C_SHELL) {
        translate([XR, -22, -PHONE_T - 2]) cube([2.4, 44, PHONE_T + 2 + 8.4]);
        translate([XR, -27, 3.4]) cube([10, 54, 5]);
    }
    color(C_TEAL) translate([XR - 2.0, -22, -PHONE_T - 2]) cube([4.4, 44, 1.8]);
    color(C_TEAL) translate([XR - 0.2, -20, -PHONE_T]) cube([0.2, 40, PHONE_T]);
}
module coil(x0, x1, y, z, r = 3, wire = 0.9, turns = 9) {
    n = turns * 10;
    color("#9aa0a6") for (i = [0 : n - 1]) {
        a0 = turns * 360 * i / n;          a1 = turns * 360 * (i + 1) / n;
        rod([x0 + (x1 - x0) * i / n, y + r * cos(a0), z + r * sin(a0)],
            [x0 + (x1 - x0) * (i + 1) / n, y + r * cos(a1), z + r * sin(a1)], wire);
    }
}
module rods_springs() {
    for (s = [-1, 1]) {
        color("#c8ccd0") rod([XR + 10, s * 24, 5.9], [X_BRK + 10, s * 24, 5.9], 3);
        coil(XR + 10, X_BRK, s * 24, 5.9);
    }
    color("#c8ccd0") for (s = [-1, 1]) translate([X_BRK + 10, s * 24, 5.9]) rotate([0, 90, 0]) cylinder(d = 5, h = 1.6);
}

// -------------------------------------------------------------- head --------
module outer(i = 0) translate([0, 0, Z0]) rbox(-HW / 2, HW / 2, HD, ZTOP - Z0, 9, 4, 2, i);
module hwall() { difference() { outer(0); outer(WALL); } }

module cuts_head() {
    translate([HW / 2, 0, 26]) cube([30, 29.2, 10.2], center = true);               // tray slot (z 20.9..31.1)
    translate([-HW / 2, 0, 14.4]) slot_x(10, 9.4, 3.4);                             // USB-C
    translate([-22, 0, ZTOP]) cylinder(d = 3.2, h = 6, center = true);              // status LED pipe
    translate([23.5, 0, ZTOP]) cylinder(d = 7.4, h = 6, center = true);             // power button
    translate([0, 0, Z0]) cylinder(d = 20, h = 6, center = true);                   // lens ring pass-through
}
module head_lower() {
    color(C_SHELL) difference() {
        intersection() { hwall(); translate([-50, -40, 0]) cube([100, 80, SPLIT - 0.15]); }
        cuts_head();
    }
}
module head_upper() {
    color(C_SHELL) difference() {
        intersection() { hwall(); translate([-50, -40, SPLIT + 0.15]) cube([100, 80, 40]); }
        cuts_head();
    }
}
module head_grips() {   // TPU side bumpers
    color(C_TEAL) for (s = [-1, 1]) difference() {
        intersection() {
            difference() { outer(-1); outer(0.8); }
            translate([-24, s > 0 ? 0 : -40, 8]) cube([48, 40, 32]);
        }
        for (gx = [-16 : 8 : 16]) translate([gx, 0, 24]) cube([2, 100, 50], center = true);
    }
}
module lens_ring() {   // clip-on macro lens, f ~ 20 mm
    color("#222") difference() {
        translate([0, 0, Z0]) cylinder(d = 18, h = 5.6);
        translate([0, 0, Z0 - 1]) cylinder(d = 12.4, h = 8);
    }
    color([0.7, 0.85, 1, 0.5]) translate([0, 0, 8.4]) cylinder(d = 12, h = 1.2);
}
module bellows() {
    color(C_BLACK) difference() {
        hull() {
            translate([0, 0, 9.6]) cylinder(d = 14, h = 0.1);
            translate([0, 0, 21.7]) cube([22, 22, 0.1], center = true);
        }
        hull() {
            translate([0, 0, 9.5]) cylinder(d = 12, h = 0.1);
            translate([0, 0, 21.9]) cube([20, 20, 0.1], center = true);
        }
    }
}
module uv_diode() {
    color(C_PCB) translate([0, 6.5, 19.4]) translate([-6, -4, 0]) cube([12, 8, 0.8]);
    color("#3a2a5a") translate([0, 6.5, 20.2]) cylinder(d = 5, h = 1.6);
}
module tray() {
    translate([TRAY, 0, 0]) {
        color(C_SHELL) difference() {
            translate([-26, -13.6, 22]) cube([58, 27.2, 2]);
            translate([-14, -8, 21]) cube([28, 16, 4]);                            // camera window
        }
        color(C_SHELL) for (s = [-1, 1]) translate([-26, s > 0 ? 12.2 : -13.6, 24]) cube([58, 1.4, 4.5]);
        color(C_SHELL) translate([-26, -13.6, 24]) cube([1.5, 27.2, 4.5]);
        color(C_TEAL) difference() {
            hull() for (sy = [-1, 1], sz = [-1, 1])
                translate([32, sy * 11, 25.5 + sz * 3.5]) rotate([0, 90, 0]) cylinder(r = 2.5, h = 3.5);
            translate([36, 0, 29]) rotate([0, 90, 0]) cylinder(d = 9, h = 3, center = true);
        }
    }
}
module cartridge() {   // identical 24 x 50 x 6 card; colour patches face the camera (underside)
    translate([TRAY, 0, 0]) {
        color("#f2f2ee", 0.9) difference() {
            translate([-25, -12, 24]) cube([50, 24, 6]);
            translate([0, 0, 23]) cylinder(d = 14, h = 8);
            translate([19, 0, 29]) cylinder(d = 3, h = 2);
        }
        color(C_FLUID, 0.85) translate([0, 0, 26.9]) cylinder(d = 14, h = CELL_PATH);
        color(C_CLEAR) translate([0, 0, 25.9]) cylinder(d = 15, h = 1);
        color(C_CLEAR) translate([0, 0, 26.9 + CELL_PATH]) cylinder(d = 15, h = 1);
        for (p = [[-10.5, -3, "#ffffff"], [-10.5, 3, "#9a9a9a"], [10.5, -3, "#c0392b"], [10.5, 3, "#f1c40f"]])
            color(p[2]) translate([p[0] - 1.5, p[1] - 1.5, 23.9]) cube([3, 3, 0.1]);
    }
}
module led_assy() {
    color(C_BLACK) difference() {                                                   // light-seal gasket
        translate([-14, -14, 30.1]) cube([28, 28, 1.3]);
        translate([-11.5, -11.5, 30]) cube([23, 23, 2]);
    }
    color("#e8e8e8", 0.6) translate([-11, -11, 30.4]) cube([22, 22, 1.2]);          // diffuser
    translate([0, 0, 33]) pcb(28, 28);
    for (p = [[-4.5, -4.5, "#7a3cff"], [4.5, -4.5, "#2255ff"], [-4.5, 4.5, "#ffffff"], [4.5, 4.5, "#38c84a"]])
        color(p[2]) translate([p[0], p[1], 31.6]) cylinder(d = 3, h = 1.4);
}
module electronics() {
    color("#c9c9c9") translate([-29.4, -15, 6]) cube([20, 30, 5]);                 // LiPo 502030 laid flat
    translate([-19.4, 0, 11.2]) pcb(20, 30);
    color("#222") translate([-19.4, 0, 12.8 + 1.2]) cube([13.2, 16.6, 2.4], center = true);   // ESP32-C3-MINI
    color("#333") translate([-26.4, 0, 12.8 + 1.6]) cube([7.4, 9, 3.2], center = true);        // USB-C receptacle
    color("#f5a742") translate([-29.0, 0, 23]) cube([0.2, 8, 21], center = true);              // flex to LED board
    color(C_BLACK) translate([-28.2, 0, 26]) cube([3, 6, 5], center = true);                   // tray interlock
    color(C_SHELL) translate([-29.8, -4, 24]) cube([1.5, 8, 4]);
}
module controls() {
    color(C_TEAL) translate([23.5, 0, ZTOP - 1.8]) cylinder(d = 7, h = 2.4);
    color("#bbb") translate([23.5, 0, 38]) cylinder(d = 3, h = 4);
    color("#3498db") translate([-22, 0, ZTOP - 1.5]) cylinder(d = 3, h = 1.8);
}
module slide_locks() {
    color(C_TEAL) for (s = [-1, 1]) translate([-14, s * (HD / 2 + 0.3), 10])
        rotate([s * 90, 0, 0]) { cylinder(d = 9, h = 4); }
    color("#999") for (s = [-1, 1]) translate([-14, s * (HD / 2 - 3), 10]) rotate([s * 90, 0, 0]) cylinder(d = 3, h = 6);
}

// -------------------------------------------------------------- assembly ----
module head() {
    translate([x_adj, 0, 0]) {
        translate([0, 0, ex(60)]) { head_upper(); controls(); }
        head_lower();
        translate([0, 0, ex(20)]) head_grips();
        slide_locks();
        translate([0, 0, ex(-12)]) lens_ring();
        translate([0, 0, ex(-6)]) bellows();
        translate([0, 0, ex(-6)]) uv_diode();
        translate([0, 0, ex(45)]) led_assy();
        translate([0, 0, ex(15)]) electronics();
        translate([ex(60), 0, ex(24)]) { tray(); cartridge(); }
    }
}
module clip() {
    bridge();
    translate([ex(30), 0, 0]) { sliding_jaw(); rods_springs(); }
    head();
}
module head_internals() {
    lens_ring(); bellows(); uv_diode(); led_assy(); electronics(); tray(); cartridge();
}
module head_shells() { head_lower(); head_upper(); head_grips(); }

module annotations() {
    dim3([XL - 5, -27, 0], [X_BRK + 6, -27, 0], [0, -14, -14], str(X_BRK + 6 - (XL - 5)), 6);
    dim3([-HW / 2, -HD / 2, Z0], [-HW / 2, -HD / 2, ZTOP], [-14, -6, 0], "43", 6, "x");
    dim3([XL, -27, -PHONE_T - 6], [XR, -27, -PHONE_T - 6], [0, -8, -2], str(PHONE_W), 6);
    dim3([-HW / 2, -HD / 2, 50], [HW / 2, -HD / 2, 50], [0, -8, 4], "64", 6);
    label3("SAMPLE TRAY + CARTRIDGE", [30, -10, 26], [40, -50, 70]);
    label3("MACRO LENS RING", [0, -9, 6], [-60, -50, 30]);
    label3("SLIDING JAW + SPRING", [XR + 4, -24, 6], [60, -50, 40]);
    label3("FIXED JAW (TPU LIP)", [XL - 2, -20, -6], [-60, -50, 10]);
    label3("LED + UVC BOARD", [0, 0, 34], [-70, -50, 85]);
    label3("BLE MCU + LIPO", [-25, -8, 12], [-100, -50, 60]);
    label3("USB-C", [-32, 0, 14.4], [-110, -20, 20]);
}

// ================================================================ SHEETS ====
PX = 62;  PY = 222;
FX = 62;  FY = 128;
SX = 232; SY = 128;
AX = 62;  AY = 60;

module close2() { offset(delta = -0.4) offset(delta = 0.4) children(); }
module sil_top()   { close2() projection() children(); }
module sil_front() { close2() projection() rotate([-90, 0, 0]) children(); }
module sil_side()  { close2() projection() rotate([-90, 0, 0]) rotate([0, 0, -90]) children(); }
module sec_long()  { projection() rotate([-90, 0, 0])
                         intersection() { children(); translate([-300, -0.05, -50]) cube([600, 0.1, 200]); } }

module cut_solids()     { bridge(); sliding_jaw(); head_shells(); }   // hatched in section
module cut_internals()  { head_internals(); phone(); }               // outlined in section

module phone_plan_outline() {
    intersection() {
        translate([-60, -40]) square([220, 80]);
        translate([XL, -(PHONE_L - CAM_FROM_TOP)]) offset(r = 10) offset(delta = -10) square([PHONE_W, PHONE_L]);
    }
}

module sheet_ga() {
    sheet_frame();
    title_block("CLIP GA", "OLEOLENS CLIP OL-C1 (PHONE ATTACHMENT)", "OL-C1-GA-0001", "1:1", "MASS 0.14 KG");
    // PLAN
    translate([PX, PY]) {
        outline2(0.5) sil_top() clip();
        outline2(0.15) phone_plan_outline();
        translate([-5, -50]) txt("PHONE (REF)", 2.4, "left", "center");
        centre2([0, 0], 8);
        outline2(0.25) circle(d = 14);
        dim_h(XL - 5, X_BRK + 6, 40, 27, 27);
        dim_h(XL, XR, -38, -22, -22, str(PHONE_W, " PHONE WIDTH (64-80)"));
        dim_v(-27, 27, XL - 14, XL - 5, XL - 5);
        balloon(16, [23.5, 0], [34, 44]);
        balloon(3, [XR + 5, 15], [XR + 14, 44]);
        balloon(4, [XR + 30, 24], [XR + 36, 44]);
    }
    caption("PLAN VIEW", [PX + 20, PY - 56], "1:1");
    // FRONT
    translate([FX, FY]) {
        outline2(0.5) sil_front() clip();
        translate([XL, -PHONE_T]) outline2(0.15) square([PHONE_W, PHONE_T]);
        dim_h(XL - 5, X_BRK + 6, -PHONE_T - 10, -PHONE_T - 2, -PHONE_T - 2);
        dim_v(Z0, ZTOP, XL - 22, -HW / 2 + x_adj, -HW / 2 + x_adj, "43");
        dim_v(-PHONE_T - 2, 0, XL - 12, XL - 5, XL - 5, "10.6");
    }
    caption("FRONT VIEW (-Y)", [FX + 20, FY - 28], "1:1");
    // SIDE (looking from +X)
    translate([SX, SY]) {
        outline2(0.5) sil_side() clip();
        dim_h(-27, 27, -PHONE_T - 10, -PHONE_T - 2, -PHONE_T - 2);
        dim_v(Z0, ZTOP, 38, 23, 23, "43");
    }
    caption("SIDE VIEW (PORT)", [SX, SY - 28], "1:1");
    part_list(298, 282, [
        [1, "BRIDGE PLATE + FIXED JAW", 1], [2, "TPU JAW LIPS + LINERS", 2], [3, "SLIDING JAW", 1],
        [4, "GUIDE ROD D3 SS", 2], [5, "CLAMP SPRING", 2], [6, "HEAD LOWER HOUSING", 1],
        [7, "HEAD UPPER HOUSING", 1], [8, "MACRO LENS RING F20", 1], [9, "LIGHT BELLOWS, SILICONE", 1],
        [10, "SAMPLE TRAY, PA12", 1], [11, "CARTRIDGE (SHARED P/N)", 1], [12, "LED BOARD 446/UVC/W/G", 1],
        [13, "SIC UV PHOTODIODE", 1], [14, "BLE MCU BOARD ESP32-C3", 1], [15, "LIPO 502030", 1],
        [16, "POWER BUTTON", 1], [17, "USB-C PORT", 1], [18, "TRAY INTERLOCK", 1], [19, "SLIDE LOCK KNOB", 2]
    ], 112, 5.4);
    notes_block(16, 40, [
        "1. ALL DIMENSIONS IN MILLIMETRES. DO NOT SCALE DRAWING. ORIGIN = PHONE MAIN LENS CENTRE.",
        "2. PHONE BACK FACE = PLANE Z=0. JAWS GRIP 64 TO 80 MM WIDE PHONES; HEAD SLIDES +/-4 MM FOR ALIGNMENT.",
        "3. SAMPLE PATH LENGTH 2.0 MM. UVC LED INTERLOCKED BY TRAY SWITCH (18).",
        "4. GENERAL TOLERANCES: LINEAR +/-0.3."
    ]);
}

module app_wireframe(x, y, k = 0.9) {   // phone app result screen
    translate([x, y]) scale(k) {
        outline2(0.8) offset(r = 8) offset(delta = -8) square([72, 150], center = true);
        translate([0, 62]) txt("OLEOLENS", 5, "center", "center");
        translate([0, 34]) outline2(0.4) square([58, 42], center = true);
        translate([0, 34]) txt("LIVE CAMERA", 3, "center", "center");
        translate([0, 34]) outline2(0.3) circle(d = 20);
        for (r = [0 : 2]) {
            translate([-27, 6 - r * 12]) txt(["DYE / CAROTENE", "FFA", "PV"][r], 2.6, "left", "center");
            translate([20, 6 - r * 12]) outline2(0.3) square([12, 5], center = true);
            translate([30, 6 - r * 12]) circle(d = 4, $fn = 24);
        }
        translate([0, -38]) outline2(0.5) square([58, 18], center = true);
        translate([0, -38]) txt("PASS / CAUTION / FAIL", 3.4, "center", "center");
        translate([0, -62]) outline2(0.4) square([40, 10], center = true);
        translate([0, -62]) txt("START TEST", 3.2, "center", "center");
    }
}

// analytic Y=0 profile of housings and clamp
module head_outer2() {
    hull() for (sx = [-HW / 2 + 4, HW / 2 - 4]) {
        translate([sx, ZTOP - 4]) circle(4);
        translate([sx, Z0 + 2]) circle(2);
    }
}
module clip_profile2d() {
    difference() {
        difference() { head_outer2(); offset(delta = -WALL) head_outer2(); }
        translate([20, 20.9]) square([20, 10.2]);
        translate([-40, 12.7]) square([13, 3.4]);
        translate([-10, 0]) square([20, 7]);
        translate([23.5 - 3.7, 40]) square([7.4, 10]);
        translate([-22 - 1.6, 40]) square([3.2, 10]);
    }
    translate([XL - 5, 0.4]) square([5, 3]);
    translate([22, 0.4]) square([X_BRK + 6 - 22, 3]);
    translate([XL - 5, -PHONE_T - 2]) square([2.4, PHONE_T + 2 + 3.8]);
    translate([XL - 2.6, -PHONE_T - 2]) square([4.6, 1.8]);
    translate([XR, -PHONE_T - 2]) square([2.4, PHONE_T + 2 + 8.4]);
    translate([XR - 2.0, -PHONE_T - 2]) square([4.4, 1.8]);
    translate([XR, 3.4]) square([10, 5]);
    translate([X_BRK, 3.4]) square([6, 6]);
}

module sheet_section() {
    sheet_frame();
    title_block("CLIP SECTION", "SECTION A-A (Y=0) AND APP WIREFRAME", "OL-C1-SEC-0002", "1:1", "MASS 0.14 KG");
    translate([AX, AY + 100]) {
        hatch2() clip_profile2d();
        outline2(0.4) clip_profile2d();
        outline2(0.4) sec_long() cut_internals();
        balloon(8, [0, 6], [-24, -16]);
        balloon(9, [6, 15], [20, -16]);
        balloon(10, [30, 23], [44, -16]);
        balloon(11, [8, 27], [-34, 62]);
        balloon(12, [0, 34], [14, 62]);
        balloon(14, [-20, 13], [-45, 40]);
        balloon(18, [-28, 26], [-44, 62]);
        balloon(13, [0, 21], [-14, -16]);
        dim_v(Z0, ZTOP, 40, 32, 32, "43");
        dim_v(0, 24, 52, 32, 32, "CELL AT Z=24");
    }
    caption("SECTION A-A  (HATCH = HOUSINGS + CLAMP)", [AX + 20, AY + 54], "1:1");
    app_wireframe(300, 140, 0.9);
    caption("APP RESULT SCREEN WIREFRAME", [300, 60], "0.9:1");
    part_list(298, 282, [
        [8, "MACRO LENS RING", 1], [9, "LIGHT BELLOWS", 1], [10, "SAMPLE TRAY", 1], [11, "CARTRIDGE", 1],
        [12, "LED BOARD", 1], [13, "UV PHOTODIODE", 1], [14, "BLE MCU BOARD", 1], [18, "TRAY INTERLOCK", 1]
    ], 112, 5.4);
    notes_block(16, 40, [
        "1. SECTION CUT AT Y=0. HATCHED = HOUSINGS AND CLAMP, OUTLINES = INTERNAL PARTS + PHONE (REF).",
        "2. PHONE CAMERA LOOKS UP THROUGH MACRO LENS (8) AND BELLOWS (9). LEDS (12) LIGHT FROM ABOVE.",
        "3. CARTRIDGE WINDOWS: UV-GRADE FUSED SILICA FOR THE 269 NM CHANNEL."
    ]);
}

// ================================================================ RENDER ====
if (view == "sheet_ga") sheet_ga();
else if (view == "sheet_section") sheet_section();
else {
    difference() {
        union() {
            if (show_phone) phone();
            if (view == "internals") { head_internals(); %head_shells(); bridge(); sliding_jaw(); }
            else clip();
        }
        if (cutaway) translate([-300, 0, -60]) cube([600, 300, 200]);
    }
    if (show_dims) annotations();
}
