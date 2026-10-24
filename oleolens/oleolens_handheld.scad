// ============================================================================
// OleoLens HANDHELD  (Tier 1: standalone device)
// Palm oil adulteration + quality screener: dye/carotene (446 nm + UVC 269 nm),
// FFA and PV reagent colorimetry. Own MCU (ESP32-S3), camera, display.
//
// HOW TO USE
//   1. Keep oleolens_common.scad in the same folder.
//   2. Pick a view in the Customizer (or edit `view`), press F5 (preview).
//   3. For the A3 drawing sheets choose view = sheet_ga or sheet_section,
//      press F6, then File > Export > SVG or DXF.
//   Units: millimetres. X = length (tray end is +X), Y = width, Z = height.
// ============================================================================
include <oleolens_common.scad>

/* [View] */
view = "assembly";      // [assembly, exploded, internals, tray_open, sheet_ga, sheet_section]
tray_out = 0;           // mm the tray is pulled out (tray_open sets 55)
show_dims = true;       // 3D dimensions and part labels
cutaway = false;        // slice away the +Y half to see inside

/* [Body] */
L = 160;  W = 74;
H_REAR = 26;  H_FRONT = 40;
WALL = 2.4;  SPLIT = 16;
RV = 14;  RT = 6;
X_REAR_END = -14;       // rear box ends here
X_FRONT_START = 14;     // front (optical hump) box starts here

/* [Layout] */
DISP_X = -47;           // display centre
OPT_X = 35;             // optical axis X
BTN_X = 66;  BAR_X = 52;
CELL_PATH = 2.0;        // sample path length in the cartridge, mm
TRAY_Z0 = 10;           // tray floor underside

$fn = 36;
TRAY = (view == "tray_open") ? 55 : tray_out;
function ex(k) = (view == "exploded") ? k : 0;

// ---------------------------------------------------------------- body ------
module outer(i = 0) {
    hull() {
        rbox(-L / 2, X_REAR_END, W, H_REAR, RV, RT, 2, i);
        rbox(X_FRONT_START, L / 2, W, H_FRONT, RV, RT, 2, i);
    }
}
module wall() { difference() { outer(0); outer(WALL); } }

module usb_cut() { translate([-80, 0, 16.2]) slot_x(16, 9.4, 3.4); }

module cuts() {
    translate([DISP_X, 0, H_REAR]) cube([40.8, 30.6, 20], center = true);     // display window
    translate([BTN_X, 0, H_FRONT]) cylinder(d = 10.4, h = 10, center = true); // power button
    translate([BAR_X, 0, H_FRONT]) cube([5, 36, 10], center = true);          // status light bar
    translate([8, -14.6, 9.4]) cube([90, 29.2, 10.2]);                        // tray slot
    usb_cut();
}

module upper_shell() {
    color(C_SHELL) difference() {
        intersection() { wall(); translate([-100, -60, SPLIT + 0.15]) cube([200, 120, 80]); }
        cuts();
    }
}

BOSSES = [[-62, -26], [-62, 26], [-2, -28], [-2, 28], [58, -26], [58, 26]];
module lower_shell() {
    color(C_SHELL) difference() {
        union() {
            intersection() { wall(); translate([-100, -60, -5]) cube([200, 120, 5 + SPLIT - 0.15]); }
            for (b = BOSSES) translate([b[0], b[1], WALL - 0.1]) cylinder(d = 6.4, h = 13.5);
        }
        cuts();
        for (b = BOSSES) translate([b[0], b[1], 4]) cylinder(d = 2.2, h = 20);
        for (b = BOSSES) translate([b[0], b[1], -1]) cylinder(d = 5, h = 1.6);   // screw recess
    }
}

module skin() { difference() { outer(-1.2); outer(1.0); } }

module grips() {
    color(C_TEAL) difference() {
        intersection() {
            skin();
            union() {
                translate([-40, -60, 6]) cube([80, 120, 16]);
            }
            difference() { translate([-100, -60, -3]) cube([200, 120, 60]);
                           translate([-100, -(W / 2 - 6), -10]) cube([200, W - 12, 80]); }
        }
        for (gx = [-34 : 8 : 34]) translate([gx, 0, 14]) cube([2, 100, 40], center = true);
    }
}

module rear_cap() {
    color(C_TEAL) difference() {
        intersection() { skin(); translate([-100, -60, -3]) cube([38, 120, 23]); }
        usb_cut();
    }
}

module feet() {
    color(C_BLACK) for (p = [[-60, -22], [-60, 22], [50, -22], [50, 22]])
        translate([p[0], p[1], -1.4]) cylinder(d = 8, h = 1.5);
}

// ------------------------------------------------------------ electronics ---
module main_pcb() {
    translate([-36, 0, 13]) pcb(80, 52);
    color("#222") translate([-6, 0, 14.6 + 1.6]) cube([18, 25.5, 3.2], center = true);        // ESP32-S3 module
    color(C_GOLD) translate([-6 + 9.5, 0, 14.6 + 0.4]) cube([2, 25.5, 0.8], center = true);   // antenna keep-out
    color("#333") translate([-75, 0, 14.6 + 1.6]) cube([7.4, 9, 3.2], center = true);         // USB-C receptacle
    color("#444") translate([-28, -14, 14.6 + 1]) cube([8, 6, 2], center = true);             // charger IC
    color("#444") translate([-28, 14, 14.6 + 1]) cube([10, 8, 2], center = true);             // buck-boost
    color("#555") translate([-42, 0, 14.6 + 0.6]) cube([6, 6, 1.2], center = true);           // IMU / ADC
}
module battery() {
    color("#c9c9c9") translate([-49, 0, 7.1]) cube([50, 34, 9], center = true);
    color("#e33") translate([-23.2, 0, 7.1]) cube([3, 10, 3], center = true);
}
module display() {
    translate([DISP_X, 0, 20.4]) {
        pcb(51.5, 35.5, 1.2, "#7a5c1e");
        color("#10141a") translate([-24.5, -17, 1.2]) cube([49, 34, 1.8]);
        color("#1f3a5f") translate([-20.4, -15.3, 3.0]) cube([40.8, 30.6, 0.2]);
    }
}
module led_board() {
    translate([OPT_X, 0, 4.6]) {
        pcb(28, 28);
        for (p = [[-4.5, -4.5, "#7a3cff"], [4.5, -4.5, "#2255ff"], [-4.5, 4.5, "#ffffff"], [4.5, 4.5, "#38c84a"]])
            color(p[2]) translate([p[0], p[1], 1.6]) cylinder(d = 3, h = 1.4);
    }
    color("#e8e8e8", 0.6) translate([OPT_X - 11, -11, 8.0]) cube([22, 22, 1.4]);   // diffuser
    color(C_PCB) for (sx = [-1, 1], sy = [-1, 1])
        translate([OPT_X + sx * 11, sy * 11, 2.4]) cylinder(d = 4, h = 2.2);       // standoffs
}
module camera_assy() {
    translate([OPT_X, 0, 35.4]) {
        pcb(20, 20);
        color(C_BLACK) translate([0, 0, -3]) cube([9, 9, 6], center = true);        // macro camera module
        color("#335") translate([0, 0, -6.1]) cylinder(d = 5, h = 0.4);              // lens
        color("#3a2a5a") translate([0, 7.5, -1.0]) cylinder(d = 5.6, h = 2);         // SiC UV photodiode
    }
}
module hood() {   // silicone light-tight bellows
    color(C_BLACK) difference() {
        hull() {
            translate([OPT_X, 0, 35.3]) cube([22, 22, 0.1], center = true);
            translate([OPT_X, 0, 18.2]) cube([25, 25, 0.1], center = true);
        }
        hull() {
            translate([OPT_X, 0, 35.5]) cube([20, 20, 0.1], center = true);
            translate([OPT_X, 0, 18.0]) cube([22.6, 22.6, 0.1], center = true);
        }
    }
}
module switch() {
    color(C_BLACK) translate([7.6, 0, 14.4]) cube([5, 6, 4], center = true);
    color(C_PCB) translate([4.2, 0, 13.6]) cube([2, 10, 2.4], center = true);
}

// ----------------------------------------------------------- tray + cell ----
module tray_cage() {
    color("#3b3f48") {
        for (s = [-1, 1]) translate([8, s > 0 ? 14.4 : -18, 8]) cube([69.5, 3.6, 11.2]);
        difference() {
            translate([8, -18, 19.2]) cube([69.5, 36, 1.2]);
            translate([OPT_X - 13, -13, 19]) cube([26, 26, 2]);
        }
    }
}
module tray() {
    translate([TRAY, 0, 0]) {
        color(C_SHELL) difference() {
            union() {
                translate([10, -13.6, TRAY_Z0]) cube([70, 27.2, 2]);                          // floor
                for (s = [-1, 1]) translate([10, s > 0 ? 12.2 : -13.6, 12]) cube([70, 1.4, 4.5]); // rails
                translate([60, -13.6, 12]) cube([1.5, 27.2, 4.5]);                            // cartridge stop
            }
            translate([OPT_X, 0, TRAY_Z0 - 1]) cylinder(d = 15, h = 4);                       // optical aperture
        }
        color(C_TEAL) difference() {                                                            // front plate
            hull() for (sy = [-1, 1], sz = [-1, 1])
                translate([80, sy * 11, 14.5 + sz * 3.5]) rotate([0, 90, 0]) cylinder(r = 2.5, h = 3.5);
            translate([84, 0, 18]) rotate([0, 90, 0]) cylinder(d = 9, h = 3, center = true);  // finger scoop
        }
    }
}
module cartridge() {   // 24 x 50 x 6 flat cell card, fused-silica windows
    translate([TRAY, 0, 0]) {
        color("#f2f2ee", 0.9) difference() {
            translate([10, -12, 12]) cube([50, 24, 6]);
            translate([OPT_X, 0, 11]) cylinder(d = 14, h = 8);
            translate([54, 0, 17]) cylinder(d = 3, h = 2);                                   // fill port
        }
        color(C_FLUID, 0.85) translate([OPT_X, 0, 14.9]) cylinder(d = 14, h = CELL_PATH);
        color(C_CLEAR) translate([OPT_X, 0, 13.9]) cylinder(d = 15, h = 1);
        color(C_CLEAR) translate([OPT_X, 0, 14.9 + CELL_PATH]) cylinder(d = 15, h = 1);
        for (p = [[24.5, -3, "#ffffff"], [24.5, 3, "#9a9a9a"], [45.5, -3, "#c0392b"], [45.5, 3, "#f1c40f"]])
            color(p[2]) translate([p[0] - 1.5, p[1] - 1.5, 17.95]) cube([3, 3, 0.1]);        // colour references
    }
}

// ------------------------------------------------------------ top controls --
module controls() {
    color(C_TEAL) translate([BTN_X, 0, H_FRONT - 1.8]) cylinder(d = 9.6, h = 2.4);
    color("#bbb") translate([BTN_X, 0, 30]) cylinder(d = 3.4, h = 8);
    color(C_BLACK) translate([BTN_X, 0, 28.5]) cube([6, 6, 3], center = true);
    color(C_PCB) translate([BTN_X, 0, 20.4]) cylinder(d = 6, h = 8);
    for (p = [[-12, "#2ecc71"], [0, "#f1c40f"], [12, "#e74c3c"]])
        color(p[1]) translate([BAR_X, p[0], H_FRONT - 1.2]) cube([4.4, 11, 1.2], center = false);
}

// ---------------------------------------------------------------- assembly --
module device() {
    translate([0, 0, ex(75)]) { upper_shell(); controls(); }
    lower_shell();
    translate([0, 0, ex(30)]) { grips(); }
    translate([ex(-45), 0, 0]) rear_cap();
    feet();
    translate([0, 0, ex(-30)]) battery();
    translate([0, 0, ex(14)]) { main_pcb(); switch(); }
    translate([0, 0, ex(52)]) display();
    translate([0, 0, ex(-22)]) led_board();
    translate([0, 0, ex(62)]) camera_assy();
    translate([0, 0, ex(40)]) hood();
    translate([0, 0, ex(20)]) tray_cage();
    translate([ex(70), 0, 0]) { tray(); cartridge(); }
}

module internals() {   // everything under the shells (used for sections)
    battery(); main_pcb(); switch(); display(); led_board(); camera_assy(); hood(); tray_cage(); tray(); cartridge();
}
module shells() { upper_shell(); lower_shell(); grips(); rear_cap(); }

// ---------------------------------------------------------- 3D annotations --
module annotations() {
    dim3([-L / 2, -W / 2, 0], [L / 2, -W / 2, 0], [0, -22, -3], "160", 6);
    dim3([L / 2, -W / 2, 0], [L / 2, W / 2, 0], [24, 0, -3], "74", 6, "x");
    dim3([-L / 2, -W / 2, 0], [-L / 2, -W / 2, H_FRONT], [-20, -10, 0], "40", 6, "x");
    dim3([-L / 2, -W / 2, 0], [-L / 2, -W / 2, H_REAR], [-8, -10, 0], "26", 6, "x");
    label3("TRAY + CARTRIDGE", [70, -14, 15], [96, -40, 36]);
    label3("STATUS LIGHT BAR", [BAR_X, -12, H_FRONT], [30, -46, 62]);
    label3("POWER", [BTN_X, 0, H_FRONT], [64, -46, 54]);
    label3("2.0 IPS DISPLAY", [DISP_X, -15, H_REAR], [-60, -46, 48]);
    label3("USB-C", [-80, 0, 16], [-120, -20, 30]);
    label3("MACRO CAMERA + UV PD", [OPT_X, 0, 30], [0, -46, 72]);
}

// ======================================================= 2D DRAWING SHEETS ==
PX = 118;  PY = 225;     // plan view origin (x=0,y=0 of device)
FX = 118;  FY = 120;     // front view origin (z=0 line)
SX = 262;  SY = 120;     // side view origin
AX = 118;  AY = 78;      // section A-A origin

// closing removes hairline seams so silhouettes read as one outline
module close2() { offset(delta = -0.4) offset(delta = 0.4) children(); }
module sil_top()   { close2() projection() children(); }
module sil_front() { close2() projection() rotate([-90, 0, 0]) children(); }
module sil_side()  { close2() projection() rotate([-90, 0, 0]) rotate([0, 0, -90]) children(); }
// robust longitudinal section: thin slab at Y=0, then project
module sec_long()  { projection() rotate([-90, 0, 0])
                         intersection() { children(); translate([-200, -0.05, -50]) cube([400, 0.1, 200]); } }

module sheet_ga() {
    sheet_frame();
    title_block("HANDHELD GA", "OLEOLENS HANDHELD OL-H1", "OL-H1-GA-0001", "1:1", "MASS 0.28 KG");
    // PLAN
    translate([PX, PY]) {
        outline2(0.5) sil_top() device();
        centre2([OPT_X, 0], 8);
        translate([DISP_X, 0]) outline2(0.25) square([40.8, 30.6], center = true);
        translate([BAR_X, 0]) outline2(0.25) square([5, 36], center = true);
        translate([BTN_X, 0]) outline2(0.25) circle(d = 10.4);
        translate([OPT_X, 0]) outline2(0.25) circle(d = 14);
        dim_h(-80, 80, 46, 37, 37);
        dim_v(-37, 37, -92, -80, -80);
        balloon(13, [DISP_X + 10, 8], [DISP_X + 10, 52]);
        balloon(16, [BAR_X, 14], [BAR_X + 4, 56]);
        balloon(15, [BTN_X, 4], [BTN_X + 12, 50]);
    }
    caption("PLAN VIEW", [PX, PY - 50], "1:1");
    // FRONT
    translate([FX, FY]) {
        outline2(0.5) sil_front() device();
        dim_h(-80, 80, -12, 0, 0);
        dim_v(0, 26, -92, -80, -80);
        dim_v(0, 40, 92, 80, 80);
    }
    caption("FRONT VIEW (-Y)", [FX, FY - 30], "1:1");
    // SIDE
    translate([SX, SY]) {
        outline2(0.5) sil_side() device();
        dim_h(-37, 37, -12, 0, 0);
    }
    caption("SIDE VIEW (PORT)", [SX, SY - 30], "1:1");
    part_list(300, 282, [
        [1, "UPPER SHELL, PC/ABS", 1], [2, "LOWER SHELL, PC/ABS", 1], [3, "SIDE GRIP, TPU 70A", 2],
        [4, "REAR CAP, TPU 70A", 1], [5, "SAMPLE TRAY, PA12", 1], [6, "CARTRIDGE, COC + FUSED SILICA", 1],
        [7, "MACRO CAMERA MODULE", 1], [8, "SIC UV PHOTODIODE 269 NM", 1], [9, "LIGHT HOOD, SILICONE", 1],
        [10, "LED BOARD 446/UVC/WHITE/GREEN", 1], [11, "MAIN PCB, ESP32-S3", 1], [12, "LIPO 903450 2000 MAH", 1],
        [13, "2.0 IPS TFT 240x320", 1], [14, "TRAY CAGE", 1], [15, "POWER BUTTON", 1],
        [16, "STATUS LIGHT BAR (3 SEG)", 1], [17, "TRAY INTERLOCK SWITCH", 1], [18, "USB-C PORT", 1]
    ], 108, 5.6);
    notes_block(16, 40, [
        "1. ALL DIMENSIONS IN MILLIMETRES UNLESS OTHERWISE STATED. DO NOT SCALE DRAWING.",
        "2. COORDINATES: X LENGTH (TRAY END +X), Y WIDTH, Z HEIGHT. OPTICAL AXIS AT X=35, Y=0.",
        "3. SAMPLE PATH LENGTH 2.0 MM. UVC LED IS INTERLOCKED BY TRAY SWITCH (17).",
        "4. GENERAL TOLERANCES: LINEAR +/-0.3, SHELL WALL 2.4 NOM."
    ]);
}

module ui_wireframe(x, y, k = 2) {   // 2.0" display, 240x320 landscape, drawn at k x
    translate([x, y]) scale(k) {
        outline2(0.5) square([40.8, 30.6], center = true);
        translate([0, 11]) txt("OLEOLENS", 2.4, "center", "center");
        line2([-18, 8], [18, 8], 0.2);
        for (r = [0 : 2]) {
            translate([-17, 4 - r * 5.5]) txt(["DYE / CAROTENE", "FFA", "PV"][r], 1.6, "left", "center");
            translate([8, 4 - r * 5.5]) outline2(0.2) square([8, 2.4], center = true);
            translate([16.5, 4 - r * 5.5]) circle(d = 2.2, $fn = 20);
        }
        translate([0, -12]) outline2(0.3) square([34, 5], center = true);
        translate([0, -12]) txt("PASS / CAUTION / FAIL", 1.7, "center", "center");
    }
}

// analytic Y=0 profile of the shells (robust; avoids slicing the hulled mesh)
module rr2(x0, x1, hh) {
    hull() for (sx = [x0 + 6, x1 - 6]) {
        translate([sx, 6 + 0]) translate([0, hh - 12]) circle(6);
        translate([sx, 2]) circle(2);
    }
}
module outer2() { hull() { rr2(-80, -14, H_REAR); rr2(14, 80, H_FRONT); } }
module shell_profile2d() {
    difference() {
        difference() { outer2(); offset(delta = -WALL) outer2(); }
        translate([DISP_X - 20.4, 16]) square([40.8, 14]);
        translate([BTN_X - 5.2, 34]) square([10.4, 10]);
        translate([BAR_X - 2.5, 34]) square([5, 10]);
        translate([8, 9.4]) square([90, 10.2]);
        translate([-90, 14.5]) square([18, 3.4]);
    }
}

module sheet_section() {
    sheet_frame();
    title_block("HANDHELD SECTION + LAYOUT", "SECTION A-A (Y=0) AND UI WIREFRAME", "OL-H1-SEC-0002", "1:1", "MASS 0.28 KG");
    translate([AX, AY + 100]) {
        hatch2() shell_profile2d();
        outline2(0.4) shell_profile2d();
        outline2(0.4) sec_long() internals();
        // part balloons (section plane Y=0)
        balloon(13, [DISP_X, 22], [DISP_X - 10, 55]);
        balloon(11, [-60, 14], [-62, 40]);
        balloon(12, [-49, 7], [-72, 14]);
        balloon(10, [OPT_X, 6], [OPT_X - 22, -14]);
        balloon(5, [70, 11], [90, -14]);
        balloon(6, [OPT_X, 15], [OPT_X + 24, -14]);
        balloon(7, [OPT_X, 32], [OPT_X - 24, 56]);
        balloon(9, [OPT_X + 10, 26], [OPT_X + 26, 56]);
        balloon(17, [8, 14], [-8, -14]);
        dim_v(0, 40, 92, 80, 80);
        dim_v(10, 18, 100, 84, 84, "TRAY 8");
        dim_h(OPT_X, 80, -26, 0, 0, "45 TO FRONT FACE");
    }
    caption("SECTION A-A  (HATCH = SHELLS)", [AX, AY + 62], "1:1");
    ui_wireframe(246, 112, 2);
    caption("DISPLAY WIREFRAME (2.0 IN, 240x320)", [246, 62], "2:1");
    part_list(300, 282, [
        [5, "SAMPLE TRAY", 1], [6, "CARTRIDGE", 1], [7, "MACRO CAMERA", 1], [9, "LIGHT HOOD", 1],
        [10, "LED BOARD", 1], [11, "MAIN PCB", 1], [12, "LIPO CELL", 1], [13, "DISPLAY", 1], [17, "INTERLOCK", 1]
    ]);
    notes_block(16, 40, [
        "1. SECTION CUT AT Y=0. HATCHED = SHELL POLYMERS, OUTLINES = INTERNAL ASSEMBLIES.",
        "2. LED BOARD (10) LIGHTS FROM BELOW, CAMERA (7) AND UV PD VIEW FROM ABOVE.",
        "3. WINDOWS IN CARTRIDGE: UV-GRADE FUSED SILICA FOR THE 269 NM CHANNEL."
    ]);
}

// ----------------------------------------------------------------- render ---
if (view == "sheet_ga") sheet_ga();
else if (view == "sheet_section") sheet_section();
else {
    difference() {
        union() {
            if (view == "internals") { internals(); %shells(); }
            else {
                device();
                // tray follows tray_out in assembly views
            }
        }
        if (cutaway) translate([-200, 0, -50]) cube([400, 200, 200]);
    }
    if (show_dims) annotations();
}
