"""
Build the Trackside setup guide PDF.

Screenshots live in docs/manual/images (captured from the FrSky Velox VX10
simulator). Output: docs/Trackside-Setup-Guide.pdf

Usage:
    python bin/manual/build_manual.py
Requires: reportlab (pip install reportlab)
"""

from datetime import date
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image, KeepTogether, ListFlowable, ListItem, PageBreak, Paragraph,
    SimpleDocTemplate, Spacer, Table, TableStyle,
)

REPO = Path(__file__).resolve().parents[2]
IMG = REPO / "docs" / "manual" / "images"
OUT = REPO / "docs" / "Trackside-Setup-Guide.pdf"
VERSION = "0.1.0"

ACCENT = colors.HexColor("#F2A23A")     # Ethos-style amber
INK = colors.HexColor("#1D232B")
MUTED = colors.HexColor("#5B6573")
NOTE_BG = colors.HexColor("#FFF6E8")
WARN_BG = colors.HexColor("#FDECEA")
RULE = colors.HexColor("#D9DEE5")

base = getSampleStyleSheet()
S = {
    "title": ParagraphStyle("title", parent=base["Title"], fontName="Helvetica-Bold", fontSize=34,
                            leading=40, textColor=INK, alignment=TA_CENTER, spaceAfter=6),
    "subtitle": ParagraphStyle("subtitle", parent=base["Normal"], fontName="Helvetica", fontSize=14,
                               leading=19, textColor=MUTED, alignment=TA_CENTER),
    "h1": ParagraphStyle("h1", parent=base["Heading1"], fontName="Helvetica-Bold", fontSize=18,
                         leading=22, textColor=INK, spaceBefore=4, spaceAfter=8, keepWithNext=1),
    "h2": ParagraphStyle("h2", parent=base["Heading2"], fontName="Helvetica-Bold", fontSize=12.5,
                         leading=16, textColor=INK, spaceBefore=8, spaceAfter=4, keepWithNext=1),
    "body": ParagraphStyle("body", parent=base["Normal"], fontName="Helvetica", fontSize=10.5,
                           leading=15, textColor=INK, spaceAfter=6),
    "step": ParagraphStyle("step", parent=base["Normal"], fontName="Helvetica", fontSize=10.5,
                           leading=15, textColor=INK),
    "caption": ParagraphStyle("caption", parent=base["Normal"], fontName="Helvetica-Oblique",
                              fontSize=8.5, leading=11, textColor=MUTED, alignment=TA_CENTER,
                              spaceBefore=3, spaceAfter=10),
    "cell": ParagraphStyle("cell", parent=base["Normal"], fontName="Helvetica", fontSize=9.5,
                           leading=13, textColor=INK),
    "cellb": ParagraphStyle("cellb", parent=base["Normal"], fontName="Helvetica-Bold", fontSize=9.5,
                            leading=13, textColor=INK),
}


def p(text, style="body"):
    return Paragraph(text, S[style])


def shot(name, caption, width=120 * mm):
    path = IMG / f"{name}.png"
    img = Image(str(path), width=width, height=width * 480 / 800)
    img.hAlign = "CENTER"
    frame = Table([[img]], colWidths=[width + 2 * mm])
    frame.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 0.6, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 1 * mm), ("RIGHTPADDING", (0, 0), (-1, -1), 1 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 1 * mm), ("BOTTOMPADDING", (0, 0), (-1, -1), 1 * mm),
    ]))
    return KeepTogether([frame, p(caption, "caption")])


def pair(a, ca, b, cb):
    """Two screenshots side by side."""
    w = 82 * mm
    cells = []
    for name, cap in ((a, ca), (b, cb)):
        img = Image(str(IMG / f"{name}.png"), width=w, height=w * 480 / 800)
        cells.append([img, p(cap, "caption")])
    t = Table([[cells[0], cells[1]]], colWidths=[w + 4 * mm, w + 4 * mm])
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"),
                           ("LEFTPADDING", (0, 0), (-1, -1), 2 * mm),
                           ("RIGHTPADDING", (0, 0), (-1, -1), 2 * mm)]))
    return t


def box(text, kind="note"):
    bg = NOTE_BG if kind == "note" else WARN_BG
    edge = ACCENT if kind == "note" else colors.HexColor("#D9483B")
    t = Table([[p(text, "step")]], colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("LINEBEFORE", (0, 0), (0, -1), 3, edge),
        ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm), ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 2.5 * mm), ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5 * mm),
    ]))
    return KeepTogether([t, Spacer(1, 4 * mm)])


def steps(items, start=1):
    return ListFlowable(
        [ListItem(p(t, "step"), leftIndent=14, value=start + i) for i, t in enumerate(items)],
        bulletType="1", bulletFontName="Helvetica-Bold", bulletFontSize=10.5,
        bulletColor=ACCENT, leftIndent=14, spaceBefore=2, spaceAfter=6,
    )


def table(rows, widths, header=True):
    data = [[p(c, "cellb" if (header and r == 0) else "cell") for c in row] for r, row in enumerate(rows)]
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    style = [
        ("GRID", (0, 0), (-1, -1), 0.5, RULE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 2.5 * mm), ("RIGHTPADDING", (0, 0), (-1, -1), 2.5 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 1.6 * mm), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.6 * mm),
    ]
    if header:
        style.append(("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#EEF1F5")))
    t.setStyle(TableStyle(style))
    return KeepTogether([t, Spacer(1, 4 * mm)])


def on_page(canvas, doc):
    canvas.saveState()
    if doc.page > 1:
        canvas.setStrokeColor(RULE)
        canvas.setLineWidth(0.5)
        canvas.line(20 * mm, 14 * mm, A4[0] - 20 * mm, 14 * mm)
        canvas.setFont("Helvetica", 8.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(20 * mm, 9 * mm, f"Trackside {VERSION}  |  Setup guide for the FrSky Velox VX10")
        canvas.drawRightString(A4[0] - 20 * mm, 9 * mm, f"Page {doc.page}")
    canvas.restoreState()


def build():
    story = []

    # --- cover ---------------------------------------------------------------
    story += [Spacer(1, 38 * mm), p("Trackside", "title"),
              p("Race dashboard and drive aids<br/>for the FrSky Velox VX10", "subtitle"),
              Spacer(1, 10 * mm)]
    story.append(shot("22-dash-throttle", "The Trackside dashboard on a VX10", width=150 * mm))
    story += [Spacer(1, 6 * mm),
              p(f"<b>Setup guide</b> &nbsp;|&nbsp; Version {VERSION} &nbsp;|&nbsp; {date.today():%d %B %Y}", "subtitle"),
              PageBreak()]

    # --- intro ---------------------------------------------------------------
    story.append(p("Before you start", "h1"))
    story.append(p("This guide sets up Trackside on a car model, from a fresh model through to the dashboard. "
                   "It takes about ten minutes. Every screenshot is from the VX10."))
    story.append(table([
        ["You need", ""],
        ["Radio", "FrSky Velox VX10 with Ethos 26.2 or later"],
        ["Software", f"Trackside {VERSION} (the <b>trackside</b> folder)"],
        ["Model", "A car model. Section 2 creates one with the Ethos wizard."],
    ], [35 * mm, 135 * mm]))

    story.append(p("How Trackside connects to your car", "h2"))
    story.append(p("Trackside adds these items to your radio:"))
    story.append(table([
        ["Part", "What it is", "What it does"],
        ["<b>Throttle Aid</b> and <b>Steer Aid</b>", "Lua sources",
         "Each outputs a multiplier for one channel. Your mixes keep the normal stick line and "
         "add one <b>Multiply</b> line with the aid after it."],
        ["<b>Trackside</b>", "Telemetry sensor",
         "Created automatically. Reads 1 while Trackside runs. A logic switch built on it turns the aid "
         "lines off if Trackside stops or is missing."],
        ["<b>Trackside</b>", "System tool", "In the System menu. Holds all Trackside settings and <b>Check setup</b>, "
         "which proves the aid mixes work."],
        ["<b>Trackside</b>", "Widget", "The race dashboard."],
    ], [40 * mm, 28 * mm, 102 * mm]))
    story.append(p("Because the stick line stays in place, the car is always driven by your trigger and wheel. "
                   "The aids can only reduce them. If the Trackside scripts are missing, the safety switch from "
                   "section 4c turns the aid lines off and the car drives on the plain stick. If Trackside hits an "
                   "error, the aids let the stick straight through."))
    story.append(box("<b>The aids start OFF.</b> Every aid is OFF in a new model, so the car drives exactly as "
                     "before until you turn one on (section 7). Turn them on one at a time and try each on the "
                     "bench first."))
    story.append(box("<b>Safety.</b> Make mixer changes on the bench with the car's motor disconnected or the "
                     "radio's RF output off. Check failsafe still works afterwards.", "warn"))
    story.append(PageBreak())

    # --- 1 install -----------------------------------------------------------
    story.append(p("1. Install Trackside", "h1"))
    story.append(steps([
        "Connect the VX10 to your computer by USB and choose <b>USB storage</b> on the radio.",
        "Copy the <b>trackside</b> folder into the radio's <b>SCRIPTS</b> folder, so you have "
        "<b>SCRIPTS/trackside/main.lua</b>.",
        "Eject the radio drive safely and unplug it. The radio loads Trackside on its next start.",
    ]))
    story.append(box("Your settings are saved in <b>SCRIPTS/trackside.user</b>, a separate folder. "
                     "Updating Trackside replaces only <b>SCRIPTS/trackside</b>, so your settings are kept."))

    # --- 2 model ---------------------------------------------------------------
    story.append(p("2. Create a car model", "h1"))
    story.append(p("Skip this if you already have a car model with Steering on CH1 and Throttle on CH2. "
                   "Otherwise create one with the Ethos wizard: <b>Model &gt; Model select &gt; +</b>."))
    story.append(steps([
        "Choose <b>Car</b>.",
        "Step through the engine, steering and brake pages. The defaults are fine for most cars.",
        "On the channel page, keep <b>Steering = CH1</b> and <b>Throttle = CH2</b>. The rest of this guide uses these.",
        "Give the model a name and finish the wizard.",
    ]))
    story.append(pair("01-wizard-car", "Choose Car", "02-wizard-channels", "Steering CH1, Throttle CH2"))
    story.append(PageBreak())

    # --- 3 enable aids ---------------------------------------------------------
    story.append(p("3. Turn on Throttle Aid and Steer Aid", "h1"))
    story.append(p("Ethos only runs a Lua source, and only lists it when you pick a mix source, after you turn it "
                   "on for the model. Do this once per model."))
    story.append(steps([
        "Open <b>Model</b> and swipe to the second page.",
        "Tap <b>Lua</b>.",
        "Turn <b>Throttle Aid</b> and <b>Steer Aid</b> ON. Trackside then also creates its <b>Trackside</b> "
        "telemetry sensor, used in section 4c.",
    ]))
    story.append(shot("03-model-menu-lua", "Model menu, page 2: the Lua page", width=105 * mm))
    story.append(pair("04-lua-off", "Both start OFF", "05-lua-on", "Turn both ON"))
    story.append(PageBreak())

    # --- 4 mixes ---------------------------------------------------------------
    story.append(p("4. Add the aid mixes", "h1"))
    story.append(p("The car wizard made two mixes: <b>Steering</b> (CH1) and <b>Throttle</b> (CH2). "
                   "<b>Leave them exactly as they are.</b> You add one more mix after each."))
    story.append(box("<b>Don't</b> change the source of the existing Steering or Throttle mix to an aid. "
                     "The channel would then follow the aid's fixed value instead of your stick, and nothing would move.",
                     "warn"))
    story.append(shot("06-mixes-start", "Model > Mixes: the two mixes from the wizard", width=105 * mm))

    story.append(p("4a. Throttle", "h2"))
    story.append(steps([
        "In <b>Mixes</b>, tap <b>+</b>, choose <b>Free mix</b>, then <b>Add after: Throttle</b>.",
        "Optional: set <b>Name</b> to <i>Throttle Aid</i> so it's easy to spot in the list.",
        "Tap <b>Source</b>, scroll to the <b>Lua</b> category and pick <b>Throttle Aid</b>.",
        "Set <b>Operation</b> to <b>Multiply</b>.",
        "Scroll down and set <b>Output</b> to <b>CH2 (Throttle)</b>. A new Free mix starts with "
        "Output = <b>---</b> and does nothing until you set it.",
    ]))
    story.append(pair("07-mix-library", "+ opens the mix library: choose Free mix",
                      "08-add-after", "Add after: Throttle"))
    story.append(pair("09-source-lua", "Source: Lua > Throttle Aid",
                      "10-operation-multiply", "Operation: Multiply"))
    story.append(shot("11-output-ch2", "Output: CH2. The bar shows the result: throttle 60% gives CH2 60%.",
                      width=105 * mm))
    story.append(box("The grey box next to Source shows about <b>1024%</b>. That's Ethos showing the aid on its "
                     "internal scale, and it's expected. What counts is the channel output."))

    story.append(p("4b. Steering", "h2"))
    story.append(p("Repeat the same steps with these changes: <b>Add after: Steering</b>, source "
                   "<b>Lua &gt; Steer Aid</b>, Operation <b>Multiply</b>, Output <b>CH1 (Steering)</b>."))
    story.append(shot("12-output-ch1", "Steer Aid on CH1: wheel at -40% gives CH1 -40%", width=105 * mm))

    story.append(PageBreak())
    story.append(p("4c. Add the safety switch", "h2"))
    story.append(p("This makes the two aid lines run only while Trackside is loaded. You create one logic switch "
                   "and use it as the <b>Active condition</b> of both aid lines."))
    story.append(box("<b>Don't skip this.</b> If the Trackside scripts are missing (not copied, a new SD card, a "
                     "failed update) or stops, Ethos treats each aid as zero or holds its last value. An aid line without the safety switch then "
                     "multiplies its channel by zero: <b>no steering and no throttle</b>. With the switch, the aid "
                     "lines turn off and the car drives on the plain stick.", "warn"))
    story.append(steps([
        "Open the <b>Throttle Aid</b> mix: tap it, then <b>Edit</b>.",
        "Tap <b>Active condition</b>, choose <b>Logic switches</b>, then <b>+ Add a new logic switch</b>.",
        "Set <b>Function</b> to <b>A &gt; X</b> and <b>Source (A)</b> to <b>Telemetry &gt; Trackside</b>. "
        "Leave <b>Value (X)</b> at 0. The title <b>LS1</b> turns green while Trackside is running.",
        "Tap <b>&lt;</b> to go back. The mix's Active condition now reads <b>LS1</b>.",
        "Open the <b>Steer Aid</b> mix and set its <b>Active condition</b> to <b>Logic switches &gt; LS1</b>.",
    ]))
    story.append(pair("24-add-logic-switch", "Active condition: Logic switches > + Add a new logic switch",
                      "25-logic-switch", "LS1: A > X, Source (A) Trackside sensor, Value (X) 0"))
    story.append(shot("26-active-ls1", "The aid line with Active condition LS1", width=105 * mm))
    story.append(PageBreak())

    story.append(p("4d. Check the order", "h2"))
    story.append(p("Each stick mix must be followed by its aid. An aid line placed <b>above</b> its stick mix "
                   "does nothing. Use exactly one aid line per channel: a second Multiply line with the same aid "
                   "applies it twice."))
    story.append(shot("13-mixes-done", "Finished: Steering then Steer Aid (CH1), Throttle then Throttle Aid (CH2), "
                      "both aids on LS1", width=105 * mm))
    story.append(table([
        ["Channel", "Mix", "Source", "Operation", "Active condition"],
        ["CH1", "Steering", "Analogs > Steering (the wheel)", "Add", "Always on"],
        ["CH1", "Steer Aid", "Lua > Steer Aid", "Multiply", "LS1"],
        ["CH2", "Throttle", "Analogs > Throttle (the trigger)", "Add", "Always on"],
        ["CH2", "Throttle Aid", "Lua > Throttle Aid", "Multiply", "LS1"],
    ], [20 * mm, 26 * mm, 60 * mm, 26 * mm, 38 * mm]))
    story.append(p("To reverse a channel, use <b>Model &gt; Channels</b>. The wizard's stick mixes have no reverse "
                   "option, and a reverse on the aid line flips the whole channel."))
    story.append(PageBreak())

    # --- 5 check ---------------------------------------------------------------
    story.append(p("5. Check it works", "h1"))
    story.append(p("With every aid OFF, a working setup looks the same as no setup. The <b>Aid Test</b> in the "
                   "Trackside tool proves the mixes work: it pulses both aids between x1.0 and x0.5, so CH1 and CH2 "
                   "swing between full and half travel. You can watch it on the Channels page too."))
    story.append(steps([
        "Open <b>System</b> (the gear in the bottom bar), swipe to the second page and tap <b>Trackside</b>.",
        "Tap <b>Check setup</b>. <b>Trackside sensor</b> should read <b>Sending</b>, and both aids <b>x1.00</b>.",
        "Turn <b>Aid Test</b> ON, then hold the trigger and the wheel steady past 30%.",
        "Scroll down. Both results should read <b>OK: moves half as far</b>.",
        "Leave the page with the back button. The Aid Test switches off by itself (also after 60 seconds).",
    ]))
    story.append(pair("27-system-menu", "System, page 2: the Trackside tool",
                      "28-check-idle", "Check setup, Aid Test OFF"))
    story.append(shot("29-check-ok", "Aid Test ON: trigger 60% gives CH2 30%, both results OK", width=105 * mm))
    story.append(table([
        ["Result", "Meaning and fix"],
        ["OK: moves half as far", "The aid line works."],
        ["Not working: aid line missing or off",
         "The channel ignored the aid. Check the aid line exists, its Output is the right channel, it sits below "
         "the stick mix, and LS1 is green (section 4c)."],
        ["Wrong: set Operation Multiply", "The aid line is there but changes the channel the wrong way, "
                                          "usually Operation <b>Add</b>. Set it to <b>Multiply</b>."],
        ["Throttle Aid: Not running", "Turn the aid on in <b>Model &gt; Lua</b> (section 3)."],
    ], [58 * mm, 112 * mm]))
    story.append(p("The check compares the channel to the input. If your aids drive other channels than CH1 and CH2, "
                   "set <b>Throttle Channel</b> and <b>Steering Channel</b> on the tool's Inputs page."))
    story.append(PageBreak())

    # --- 6 dashboard -----------------------------------------------------------
    story.append(p("6. Add the dashboard", "h1"))
    story.append(steps([
        "Tap the <b>Screens</b> icon in the bottom bar (the square with a +).",
        "Tap <b>+</b> at the top right to add a screen.",
        "Choose <b>Full screen</b>. Trackside also works in other layouts; in full screen it adds its own header "
        "with model name, link quality, radio battery and transmit power.",
        "Tap the empty widget area, then pick <b>Trackside</b> from the widget list.",
        "Go back to the home screen and swipe to the new screen.",
    ]))
    story.append(pair("15-configure-screens", "Screens: tap + to add a screen",
                      "16-full-screen", "Choose Full screen"))
    story.append(shot("17-widget-pick", "Pick Trackside from the widget list", width=105 * mm))
    story.append(PageBreak())

    # --- 7 settings ------------------------------------------------------------
    story.append(p("7. Trackside settings", "h1"))
    story.append(p("All settings are in the Trackside tool: <b>System</b>, second page, <b>Trackside</b>. "
                   "Tap a tile to open its page; the back button returns to the menu. Settings are saved for the "
                   "current model (its name is shown at the top) when you leave a page."))
    story.append(pair("18-settings-overview", "The Trackside tool: settings and diagnostics",
                      "19-settings-set", "Inputs"))
    story.append(p("Check these first", "h2"))
    story.append(table([
        ["Setting", "Page", "What to set"],
        ["Throttle Input", "Inputs", "The control the aids read for throttle. Default: the VX10 trigger (Throttle)."],
        ["Steering Input", "Inputs", "The control the aids read for steering. Default: the VX10 wheel (Steering)."],
        ["Brake Direction", "Inputs", "Which way the trigger brakes. Pull the brake and watch the dashboard bar: "
                                      "it should turn red."],
        ["Battery Type, Cells", "Battery", "Match your packs (LiPo or LiHV). Cells = Auto detects the cell count."],
        ["Pack Capacity", "Battery", "Your pack size in mAh. Only needed if the car sends mAh used: fuel is then "
                                        "counted by mAh instead of estimated from voltage."],
        ["Fuel Callouts", "Battery", "Says \"Fuel 50 percent\" and so on at 50, 30, 20 and 10%. ON by default."],
        ["Voltage Alarm, Alarm Cell Voltage", "Battery",
         "Turn the low-voltage alarm on and choose the per-cell warning level."],
    ], [44 * mm, 26 * mm, 100 * mm]))
    story.append(p("<b>Aids Switch</b> (top of the Drive aids page): pick a switch position, for example <b>SA&#8593;</b>. "
                   "While it's in that position the aids work; in any other position every aid lets the sticks "
                   "straight through. Leave it at <b>---</b> to have the aids always on. The LS1 safety switch from "
                   "section 4c is still needed: it covers the case where Trackside isn't running at all."))
    story.append(pair("20-settings-drv", "Drive aids: Aids Switch at the top (aids OFF by default)",
                      "21-settings-volt", "Battery: alarm, Pack Capacity, Fuel Callouts"))
    story.append(p("The drive aids", "h2"))
    story.append(table([
        ["Aid (letter)", "What it does", "Try first"],
        ["ABS (A)", "Past ABS Trigger the brake pulses between full brake and Brake Floor. Dynamic pulses faster "
         "and lighter the harder you brake.", "Static, 8 Hz, Brake Floor 40%, Trigger 50%"],
        ["Traction Control (T)", "Throttle can only rise so fast; letting off is instant. 0% = 0.1 s to full, "
         "100% = 1 s.", "30% on a slippery track"],
        ["Steer Cut Throttle (S)", "Less throttle the more you steer (100% = 60% less at full lock).", "30%"],
        ["Corner Brake (C)", "Less brake the more you steer (100% = 60% less at full lock).", "30%"],
        ["Steer Limit (D)", "Less steering at high throttle, from Steer Limit Start up (100% = 60% less at "
         "full throttle).", "30% from 60%"],
    ], [36 * mm, 88 * mm, 46 * mm]))
    story.append(p("Each letter on the dashboard lights in its own colour while that aid is changing your input. "
                   "All aids are OFF by default. ABS above about 10 Hz can't be timed exactly by the radio."))
    story.append(PageBreak())

    # --- 8 dashboard tour ------------------------------------------------------
    story.append(p("8. Reading the dashboard", "h1"))
    story.append(pair("22-dash-throttle", "On throttle: the bar fills green to the right",
                      "23-dash-brake", "On the brake: the bar fills red"))
    story.append(table([
        ["Area", "Shows"],
        ["Header (full screen)", "Model name, link quality (LQ), radio battery (TX) and transmit power (PWR)."],
        ["PACK", "Car pack voltage, with the detected cell count (for example 2S) in the corner. "
                 "Green above 50%, amber below 50%, red below 20%."],
        ["CELL / BATT / MIN", "Voltage per cell, fuel left (see below), and the lowest pack voltage this session."],
        ["CUR / L1 / BEST / LAP", "Lap timing: current lap, last lap, best lap and lap count. "
                                  "The lap timer arrives in a later version."],
        ["A T S C D", "Drive aid letters: in the aid's own colour while it's working, white when it's armed, grey "
                      "when it's OFF. Struck through when the Aids Switch has turned the aids off."],
        ["Live bar", "Throttle (green) or brake (red) from the centre line. The small mark below shows the wheel position."],
    ], [42 * mm, 128 * mm]))
    story.append(p("Telemetry values show <b>--</b> until the receiver sends them."))
    story.append(p("Fuel (BATT)", "h2"))
    story.append(table([
        ["Source", "Used when", "How it works"],
        ["Fuel sensor", "The car sends a fuel sensor (for example <b>Fuel</b> from the ESC)",
         "Shown as sent. Trackside always prefers it."],
        ["mAh used", "Pack Capacity is set and the car sends mAh used",
         "Starts from the resting voltage, then counts down by mAh used."],
        ["Voltage", "Otherwise",
         "Read from the resting voltage whenever you've been off the throttle for a second. On throttle it "
         "holds, and once you've driven it never goes back up."],
    ], [28 * mm, 58 * mm, 84 * mm]))
    story.append(p("For the mAh and voltage sources Trackside creates a telemetry sensor called <b>Pack Fuel</b>, "
                   "so you can use it in logic switches, alerts or other widgets. Check setup shows which source is in use."))
    story.append(KeepTogether([p("Spoken alerts", "h2"), table([
        ["You hear", "When"],
        ["Fuel 50 percent (30, 20, 10)", "Fuel passes each level, once per pack. Fuel Callouts on the Battery page."],
        ["Battery low, 3.4 volts + vibration", "Voltage Alarm is ON and the resting cell voltage stays under Alarm Cell "
         "Voltage for 5 seconds (readings on throttle don't count). Repeats every 30 seconds."],
        ["Aid test on / Aid test off", "The Aid Test on Check setup starts or ends."],
        ["Drive aids on / Drive aids off + short buzz", "You flip the Aids Switch."],
        ["Drive aids off. Trackside error. + vibration", "A Trackside error released the aids: the car drives on the plain sticks."],
    ], [62 * mm, 108 * mm])]))
    story.append(p("Alerts use the radio's voice setting (English: default, US or UK). To use your own recording, put a "
                   "WAV with the same name in <b>SCRIPTS/trackside.user/audio</b>."))
    story.append(PageBreak())

    # --- 9 troubleshooting -----------------------------------------------------
    story.append(p("9. Troubleshooting", "h1"))
    story.append(table([
        ["Problem", "Check"],
        ["No steering or throttle at all",
         "Trackside isn't loaded and the aid lines have no safety switch. Set both aid lines' Active condition to "
         "<b>LS1</b> (section 4c), then install Trackside. Also check the Steering and Throttle mixes still use "
         "Analogs &gt; Steering and Analogs &gt; Throttle as their source."],
        ["Throttle or steering moves only a little",
         "Update Trackside to the latest version. Early test builds scaled the aid output wrongly."],
        ["The aid mix has no effect",
         "Run <b>Check setup</b> with the Aid Test (section 5): it says what is wrong. Set the Free mix's <b>Output</b> to the channel (CH2 or CH1), check that Operation is <b>Multiply</b>, "
         "and that the aid line sits <b>below</b> its stick mix. LS1 must be green (Model &gt; Logic switches)."],
        ["The aids stopped working after reinstalling Trackside",
         "If the model was changed while Trackside was missing (even a trim click), Ethos clears its Lua links. "
         "The car still drives normally. Open each aid line and pick its Lua source again. LS1 and the "
         "Trackside sensor are kept."],
        ["No Lua category when picking a source",
         "Turn on Throttle Aid and Steer Aid in <b>Model &gt; Lua</b> (section 3). "
         "This is needed once per model."],
        ["Trackside isn't in the widget list",
         "Check the folder is <b>SCRIPTS/trackside</b> with <b>main.lua</b> inside, then restart the radio."],
        ["The dashboard shows -- everywhere",
         "No telemetry yet. Values appear once the receiver is bound and sending telemetry."],
        ["The bar turns red when I accelerate",
         "Change <b>Brake Direction</b> on the tool's Inputs page."],
    ], [55 * mm, 115 * mm]))

    doc = SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm,
                            topMargin=18 * mm, bottomMargin=20 * mm,
                            title="Trackside Setup Guide", author="Trackside",
                            subject="Setting up Trackside on the FrSky Velox VX10")
    doc.build(story, onFirstPage=on_page, onLaterPages=on_page)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    build()
