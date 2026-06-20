#!/usr/bin/env python3
"""Assemble the fst_levers analysis into a PowerPoint deck.

Reads the PDFs + scenario_design.csv that fst_levers_plot.R wrote to
output/fst_levers_plots/, renders each PDF to PNG via pdftoppm, and builds
fst_levers_deck.pptx (16:9). Run from the magpie clone root, AFTER the plotter:
    python3 scripts/output/projects/fst_levers_deck.py

Mirrors the yield_gap deck workflow (pdftoppm PNG renders + python-pptx).
"""
import csv, glob, os, subprocess, sys
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor

OUT = "output/fst_levers_plots"
PNG = os.path.join(OUT, "_png")
os.makedirs(PNG, exist_ok=True)

try:
    from PIL import Image
    def aspect(p):
        w, h = Image.open(p).size
        return w / h
except Exception:
    def aspect(p):
        return 1.5  # fallback if Pillow is unavailable

def pdf_to_png(pdf, dpi=200):
    base = os.path.splitext(os.path.basename(pdf))[0]
    out = os.path.join(PNG, base)
    subprocess.run(["pdftoppm", "-png", "-r", str(dpi), "-singlefile", pdf, out],
                   check=True)
    png = out + ".png"
    return png if os.path.exists(png) else None

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
blank = prs.slide_layouts[6]

def add_title(slide, text, subtitle=None):
    tb = slide.shapes.add_textbox(Inches(0.4), Inches(0.18), Inches(12.5), Inches(1.0))
    tf = tb.text_frame; tf.word_wrap = True
    p = tf.paragraphs[0]; p.text = text
    p.font.size = Pt(24); p.font.bold = True; p.font.color.rgb = RGBColor(0x1a, 0x1a, 0x1a)
    if subtitle:
        p2 = tf.add_paragraph(); p2.text = subtitle
        p2.font.size = Pt(12); p2.font.color.rgb = RGBColor(0x55, 0x55, 0x55)

def add_image_slide(title, pdf, subtitle=None):
    if not os.path.exists(pdf):
        print("  skip (missing):", pdf); return
    png = pdf_to_png(pdf)
    if not png:
        print("  skip (render failed):", pdf); return
    s = prs.slides.add_slide(blank)
    add_title(s, title, subtitle)
    avail_w, avail_h = Inches(12.6), Inches(6.0)
    top0 = Inches(1.25)
    ar = aspect(png)
    w = avail_w; h = int(w / ar)
    if h > avail_h:
        h = avail_h; w = int(h * ar)
    left = int((prs.slide_width - w) / 2)
    s.shapes.add_picture(png, left, top0, width=int(w), height=int(h))

def add_table_slide(title, csv_path):
    if not os.path.exists(csv_path):
        print("  skip (missing):", csv_path); return
    with open(csv_path, newline="") as f:
        rows = list(csv.reader(f))
    if not rows:
        return
    s = prs.slides.add_slide(blank); add_title(s, title)
    nr, nc = len(rows), len(rows[0])
    gt = s.shapes.add_table(nr, nc, Inches(0.4), Inches(1.35),
                            Inches(12.5), Inches(min(5.8, 0.36 * nr))).table
    for j, head in enumerate(rows[0]):
        c = gt.cell(0, j); c.text = head
        pr = c.text_frame.paragraphs[0]; pr.font.size = Pt(11); pr.font.bold = True
        pr.font.color.rgb = RGBColor(0xff, 0xff, 0xff)
    for i in range(1, nr):
        for j in range(nc):
            c = gt.cell(i, j); c.text = rows[i][j]
            c.text_frame.paragraphs[0].font.size = Pt(10)

# 1. title
s0 = prs.slides.add_slide(blank)
add_title(s0, "fst_levers:  forest protection x bioenergy x diet x technological change",
          "A 2^4 food-system-transformation lever experiment (RIKEN-PIK WP2). "
          "MAgPIE, SSP2/NPI, coup2100. How do the four levers relax land / "
          "food-price / nitrogen pressure, and do they substitute one another?")

# 2. scenario design table
add_table_slide("Scenario design  (8 cube cells x {TCendo,TCbau} + BAU = 17 runs; "
                "constant backdrop on the cells: PkBudg650 carbon price + BII 0.78 + N MACC max + water EFP)",
                os.path.join(OUT, "scenario_design.csv"))

# 3+. curated figures
figs = [
    ("Feasibility (2^4 cube + BAU)", "01_feasibility_heatmap.pdf",
     "Each cell solved or not. Reference corner = NoProtect / No bioenergy / Endog. diet / TCbau."),
    ("Main effect of each lever, per outcome", "05_main_effects.pdf",
     "Reduction-positive: green = the lever REDUCES the outcome, purple = increases it."),
    ("Are the levers substituting one another?", "06_substitution_matrix.pdf",
     "Blue = substitutes (joint effect weaker than additive); red = complements; grey = additive."),
    ("Full 2^4 reference-delta decomposition", "04_decomposition_2x2x2x2.pdf",
     "4 main + 6 two-way + 4 three-way + 1 four-way effect per outcome."),
    ("Protection x bioenergy at TCendo, split by diet", "02_primary_protect_x_bio_by_diet.pdf", None),
    ("TC isolation: dTC = Y(TCendo) - Y(TCbau) per cell", "03a_tc_isolation.pdf",
     "Does protection / bioenergy / diet change how much TC moves each outcome?"),
    ("Diet isolation: dDiet = Y(DietOn) - Y(DietOff) per cell", "03b_diet_isolation.pdf",
     "Does protection / bioenergy / TC change how much the diet shift moves each outcome?"),
]
for title, fn, sub in figs:
    add_image_slide(title, os.path.join(OUT, fn), sub)

# trailing: per-outcome time series
for pdf in sorted(glob.glob(os.path.join(OUT, "ts_*.pdf"))):
    name = os.path.splitext(os.path.basename(pdf))[0]
    name = name.split("_", 2)[-1].replace("_", " ")
    add_image_slide("Time series:  " + name, pdf)

deck = os.path.join(OUT, "fst_levers_deck.pptx")
prs.save(deck)
print("wrote", deck, "with", len(prs.slides._sldIdLst), "slides")
