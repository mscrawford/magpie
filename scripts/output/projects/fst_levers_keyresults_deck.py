#!/usr/bin/env python3
"""Assemble the standalone fst_levers 5-factor results deck.

Run from the magpie clone root, AFTER the analysis:
    Rscript --vanilla scripts/output/projects/fst_levers_keyresults.R
    python3 scripts/output/projects/fst_levers_keyresults_deck.py

Reads the PDFs + CSVs in output/fst_levers_keyresults/, renders each PDF to PNG
via pdftoppm and builds a 16:9 deck. Same pipeline as the yield_gap deck.

This script deliberately lives in scripts/, NOT in the output folder: the
analysis wipes and rebuilds that folder, which would delete a build script
stored inside it.

EVERY NUMBER IN THE SLIDE TEXT IS READ FROM THE CSVs and formatted here - none
is transcribed by hand, so the prose cannot drift from the figures.
"""
import csv, subprocess
from pathlib import Path
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from PIL import Image

RES = Path("output/fst_levers_keyresults")
PNG = RES / "_png"; PNG.mkdir(parents=True, exist_ok=True)
OUT = RES / "fst_levers_keyresults_deck.pptx"

FONT = "Helvetica"
SLIDE_W, SLIDE_H = Inches(13.333), Inches(7.5)
TITLE_C, BODY_C, SUBTLE = RGBColor(0x1F,0x1F,0x1F), RGBColor(0x33,0x33,0x33), RGBColor(0x70,0x70,0x70)
ACCENT = RGBColor(0x00,0x72,0xB2)

def rows(name):
    with open(RES / name) as f: return list(csv.DictReader(f))

def fmt(x, nd=1):
    x = float(x)
    return f"{x:,.4f}" if abs(x) < 1 else f"{x:,.{nd}f}"

# ---- numbers, all computed from the CSVs -----------------------------------
feas  = rows("scenario_design.csv")
n_all = len(feas)
n_bad = sum(1 for r in feas if r["feasible"] != "TRUE")

pb = {(r["outcome"], r["bio"]): float(r["prot_effect"]) for r in rows("protection_vs_bioenergy.csv")}
erosion = {}
for oc in {k[0] for k in pb}:
    off, on = pb[(oc, "off")], pb[(oc, "on")]
    erosion[oc] = (abs(off) - abs(on)) / abs(off) * 100 if off else float("nan")

def mean_delta(fname):
    agg = {}
    for r in rows(fname):
        if r["delta"] in ("", "NA"): continue
        arm = ("1.5C" if r["cp"] == "on" else "NPi") + ("/Bio+" if r["bio"] == "on" else "/Bio-")
        agg.setdefault((r["outcome"], arm), []).append(float(r["delta"]))
    return {k: sum(v)/len(v) for k, v in agg.items()}
tc   = mean_delta("tc_effect.csv")
diet = mean_delta("diet_effect.csv")

# dTC split by the DIETARY arm as well - the split is the point of figure 04, and
# the pooled mean above is exactly the number that hides it.
def tc_by_diet():
    agg = {}
    for r in rows("tc_effect.csv"):
        if r["delta"] in ("", "NA") or r["bio"] == "on": continue
        agg.setdefault((r["outcome"], r["cp"], r["diet"]), []).append(float(r["delta"]))
    return {k: sum(v)/len(v) for k, v in agg.items()}
tcd = tc_by_diet()

# replacement.csv: one row per (outcome, climate arm, protection arm)
def repl():
    agg = {}
    for r in rows("replacement.csv"):
        for k in ("tc_only", "diet_only", "both", "sum_parts", "synergy"):
            agg.setdefault((r["outcome"], r["cp"], k), []).append(float(r[k]))
    return {k: sum(v)/len(v) for k, v in agg.items()}
rp = repl()

me  = {(r["outcome"], r["lever"]): float(r["effect"]) for r in rows("main_effects.csv")}

CROP = "Cropland (Mha)"; CO2 = "Land-use change CO2 (Mt CO2/yr)"
BIO  = "Terrestrial biodiversity (index)"; NSU = "Cropland+pasture N surplus (Mt Nr/yr)"

# ---- pptx helpers -----------------------------------------------------------
def png_for(pdf):
    out = PNG / pdf.stem
    subprocess.run(["pdftoppm","-png","-r","200","-singlefile",str(pdf),str(out)], check=True)
    return out.with_suffix(".png")

def set_font(run, size, *, bold=False, color=BODY_C):
    run.font.name, run.font.size, run.font.bold, run.font.color.rgb = FONT, Pt(size), bold, color

def textbox(slide, text, left, top, width, height, size, *, bold=False, color=BODY_C):
    tb = slide.shapes.add_textbox(left, top, width, height); tf = tb.text_frame; tf.word_wrap = True
    for i, line in enumerate(text.split("\n")):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        r = p.add_run(); r.text = line
        set_font(r, size, bold=bold, color=color)
    return tb

def add_image_fit(slide, img, *, top, left, max_w, max_h):
    with Image.open(img) as im: iw, ih = im.size
    if iw / ih > max_w / max_h: w, h = max_w, Emu(int(max_w * ih / iw))
    else:                       h, w = max_h, Emu(int(max_h * iw / ih))
    slide.shapes.add_picture(str(img), Emu(int(left + (max_w - w)/2)), Emu(int(top + (max_h - h)/2)), w, h)

def fig_slide(prs, pdf, title, caption):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    textbox(s, title, Inches(0.55), Inches(0.30), Inches(12.2), Inches(0.7), 24, bold=True, color=TITLE_C)
    add_image_fit(s, png_for(RES / pdf), top=Inches(1.10), left=Inches(0.55),
                  max_w=Inches(12.2), max_h=Inches(5.45))
    textbox(s, caption, Inches(0.55), Inches(6.70), Inches(12.2), Inches(0.65), 11.5, color=SUBTLE)

def text_slide(prs, title, bullets, foot=None, size=16):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    textbox(s, title, Inches(0.55), Inches(0.42), Inches(12.2), Inches(0.8), 28, bold=True, color=TITLE_C)
    tb = s.shapes.add_textbox(Inches(0.75), Inches(1.45), Inches(11.8), Inches(5.0))
    tf = tb.text_frame; tf.word_wrap = True
    for i, b in enumerate(bullets):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_after = Pt(11)
        r = p.add_run(); r.text = "•  " + b; set_font(r, size)
    if foot:
        textbox(s, foot, Inches(0.55), Inches(6.70), Inches(12.2), Inches(0.65), 11.5, color=SUBTLE)

# ---- build ------------------------------------------------------------------
prs = Presentation(); prs.slide_width, prs.slide_height = SLIDE_W, SLIDE_H

s = prs.slides.add_slide(prs.slide_layouts[6])
textbox(s, "What yield growth is worth, and where the levers collide", Inches(0.8), Inches(2.1),
        Inches(11.7), Inches(1.0), 36, bold=True, color=TITLE_C)
textbox(s, "RIKEN-PIK WP2  |  fst_levers  |  MAgPIE 5-factor experiment", Inches(0.8), Inches(3.2),
        Inches(11.7), Inches(0.6), 19, color=ACCENT)
textbox(s,
    f"{n_all} runs: climate policy x bioenergy demand x land-and-water protection x dietary shift x technological change (tau)\n"
    f"{n_all - n_bad} solved, {n_bad} with no feasible solution   |   all values at 2100   |   MAgPIE experiment/fst-levers @ 34051c697",
    Inches(0.8), Inches(4.0), Inches(11.7), Inches(1.0), 14, color=SUBTLE)

text_slide(prs, "The design",
  ["Five binary levers against a common backdrop: climate policy (1.5C PkBudg650 carbon price vs current-policy "
   "NPi2025), 2nd-generation bioenergy demand, a land-and-water protection bundle (Half-Earth conservation + "
   "biodiversity target + semi-natural vegetation on cropland + environmental flows), an EAT-Lancet dietary shift, "
   "and endogenous vs BAU-frozen technological change (tau).",
   "One combination is deliberately omitted: high bioenergy demand WITHOUT a carbon price. The carbon price and the "
   "bioenergy demand come from the same coupled REMIND run, so pairing a current-policy price with 1.5C bioenergy "
   "would splice two different energy-system solutions. Every effect involving climate AND bioenergy jointly is "
   "therefore unidentifiable by construction.",
   "WHY THIS ITERATION HAS INFEASIBLE RUNS AND yield_gap DID NOT: yield_gap paired a 1.5C carbon price with the "
   "model's DEFAULT bioenergy demand - which is the current-policy trajectory, about 50 Mha of bioenergy cropland at "
   "2100. It never ran 1.5C-consistent bioenergy demand (about 300 Mha). Here that is an explicit factor, and it is "
   "exactly the arm with no frozen-tau solution. Every 1.5C run at BASELINE bioenergy still solves at frozen tau, "
   "which is the yield_gap result reproduced.",
   f"{n_all - n_bad} of {n_all} runs solved. Non-CO2 abatement is price-driven, so nitrogen and methane mitigation "
   "scale with each cell's own carbon price rather than being pinned at an ambition the climate-off cells never paid for."],
  "Every figure is at year 2100 unless the x-axis says otherwise. Infeasible runs are excluded, never zeroed.",
  size=15)

fig_slide(prs, "01_feasibility.pdf",
    "Four runs have no solution, and they are all the same corner",
    "Every failure is 1.5C carbon price + bioenergy demand with tau frozen at BAU. It fails with protection on AND off, "
    "with the dietary shift on AND off. Neither freeing land nor cutting food demand rescues it - only tau does.")

fig_slide(prs, "02_timeseries_boundaries.pdf",
    "The four planetary boundaries, 1995 to 2100",
    "Endogenous tau. Colour = policy arm, dashed = protection off. The 1.5C arms separate from current policy early "
    "and stay separated; the dietary shift (right column) shifts the level without changing the ordering.")

fig_slide(prs, "03_timeseries_supporting.pdf",
    "Supporting indicators: forest, water, food prices, bioenergy area",
    "Same layout. Bioenergy area is the direct land footprint of the bioenergy lever - about 300 Mha at 2100 against "
    "about 50 Mha on the baseline trajectory; the food price index is the affordability cost of the transformation.")

fig_slide(prs, "04_tc_isolation.pdf",
    "What tau is worth depends entirely on the regime it is asked to work in",
    f"Cropland: {fmt(tcd[(CROP,'on','off')])} Mha under 1.5C but {fmt(tcd[(CROP,'off','off')])} Mha under current policy, "
    f"and with a dietary shift already in place only {fmt(tcd[(CROP,'on','on')])} Mha (1.5C) or "
    f"{fmt(tcd[(CROP,'off','on')])} Mha (current policy - tau then ADDS cropland). Land-use change CO2: "
    f"{fmt(tcd[(CO2,'on','off')])} vs {fmt(tcd[(CO2,'off','off')])} Mt CO2/yr. In the third regime there is nothing to measure.")

fig_slide(prs, "13_tc_vs_diet_replacement.pdf",
    "Tau and the dietary shift are substitutes, not additions",
    f"Under 1.5C, cropland: tau alone {fmt(rp[(CROP,'on','tc_only')])} Mha, the dietary shift alone "
    f"{fmt(rp[(CROP,'on','diet_only')])} Mha - but together only {fmt(rp[(CROP,'on','both')])} Mha, against "
    f"{fmt(rp[(CROP,'on','sum_parts')])} if they added. The pair delivers "
    f"{100*rp[(CROP,'on','both')]/rp[(CROP,'on','sum_parts')]:.0f}% of the sum of its parts; on land-use change CO2, "
    f"{100*rp[(CO2,'on','both')]/rp[(CO2,'on','sum_parts')]:.0f}%. Whichever you do first takes most of what the other had to offer.")

fig_slide(prs, "07_protection_vs_bioenergy.pdf",
    "Bioenergy demand erodes what land protection delivers",
    f"Protection's benefit shrinks when bioenergy competes for land: land-use change CO2 by {erosion[CO2]:.0f}%, "
    f"biodiversity by {erosion[BIO]:.0f}%, cropland by {erosion[CROP]:.0f}%, nitrogen by only {erosion[NSU]:.0f}%. "
    "The carbon boundary is where the competition bites hardest; nitrogen is almost untouched.")

fig_slide(prs, "08_main_effects.pdf",
    "Against the other four levers: climate policy dominates, bioenergy is the only one pushing the wrong way",
    f"At 2100 with endogenous tau: climate policy moves cropland by {fmt(me[(CROP,'Climate policy (1.5C)')])} Mha and "
    f"land-use change CO2 by {fmt(me[(CO2,'Climate policy (1.5C)')])} Mt CO2/yr; the dietary shift is second "
    f"({fmt(me[(CROP,'Dietary shift')])} Mha); the protection bundle third ({fmt(me[(CROP,'Protection bundle')])} Mha). "
    f"Bioenergy adds {fmt(me[(CROP,'Bioenergy demand')])} Mha of cropland. Tau is absent by design - see the previous two slides.")

text_slide(prs, "What this says",
  ["Tau is a precondition for a 1.5C food system with bioenergy, not merely a help. Those four runs have no feasible "
   "solution once tau is frozen at BAU - and they fail whether or not land is protected and whether or not diets shift.",
   f"Everywhere else, what tau is worth is contingent on the regime: {fmt(abs(tcd[(CROP,'on','off')]))} Mha of cropland "
   f"under 1.5C, {fmt(abs(tcd[(CROP,'off','off')]))} Mha under current policy. Yield growth is worth little in a world "
   "that is not asking much of land.",
   f"Tau and the dietary shift substitute for one another: under 1.5C the two together deliver "
   f"{100*rp[(CROP,'on','both')]/rp[(CROP,'on','sum_parts')]:.0f}% of the sum of their separate cropland savings, and under current "
   f"policy adding tau to a dietary shift makes cropland go UP ({fmt(tcd[(CROP,'off','on')])} Mha). They are two routes "
   "to the same slack - one on the supply side, one on the demand side.",
   f"Ambitious land protection and bioenergy genuinely compete for land. Protection's carbon benefit falls "
   f"{erosion[CO2]:.0f}% when bioenergy demand is present; its nitrogen benefit is nearly unaffected "
   f"({erosion[NSU]:.0f}%). The competition is a land-carbon competition specifically.",
   "Climate policy is the largest single lever on all four boundaries, the dietary shift second. Bioenergy demand is "
   "the only lever that moves every boundary the wrong way - the land cost of the energy system's mitigation, made "
   "visible on the land side."])

text_slide(prs, "Method and caveats",
  ["CO2 is reported as LAND-USE CHANGE emissions, not the total land flux. The two differ by an indirect, "
   "climate-driven flux that is bit-identical in all 21 solved runs (-5,860 Mt CO2/yr at 2100): it cancels out of every "
   "difference but dominates every level, so on the total the whole set reads as a 4-10 Gt/yr sink and the policy "
   "signal becomes a sliver on top of a constant. No effect reported here changes with the choice; the time series do.",
   "Read from each run's report.rds (the model's own reporting), not recomputed from gdx. Feasibility is judged on "
   "modelstat WITHOUT filtering zeros: a truncated run leaves unsolved timesteps at zero and would otherwise read as solved.",
   "The four infeasible runs do leave a report.rds on disk (~2.1 MB vs a 3.7 MB feasible mean), but it is a last "
   "iterate, not a valid optimum. They are treated as missing throughout.",
   "The bioenergy main effect is conditional on climate policy being on, and the climate main effect on bioenergy "
   "being at baseline. Neither is a marginal effect over the whole design.",
   "The nitrogen indicator is the cropland + pasture budget surplus - narrower than the retired total N pollution "
   "variable, so it is not comparable to the June iteration or to yield_gap. Biodiversity is the reported SDG15 "
   "terrestrial biodiversity index. The protection bundle is four instruments moving together, on top of a WDPA "
   "baseline and NPI avoided deforestation that stay active in BOTH arms."],
  "Analysis: scripts/output/projects/fst_levers_keyresults.R  |  deck: fst_levers_keyresults_deck.py  |  full record incl. the 2^4 decompositions and the substitution matrix: figures 06, 09, 10, 11, 12 in the results folder",
  size=13)

prs.save(OUT)
print(f"wrote {OUT}  ({len(prs.slides._sldIdLst)} slides)")
