#!/usr/bin/env python3
"""Assemble the fst_levers COLLEAGUE BRIEFING deck.

    Rscript --vanilla scripts/output/projects/fst_levers_keyresults.R
    python3 scripts/output/projects/fst_levers_briefing_deck.py

A narrative deck for briefing colleagues: what we asked, what we found, what it
means. Distinct from fst_levers_keyresults_deck.py, which is the complete
results record (12 figures, full decomposition, method and caveat slides).
Both read the same figures and CSVs; this one selects and sequences.

Every number in the slide text is read from the CSVs, never transcribed.
"""
import csv, subprocess
from pathlib import Path
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from PIL import Image

RES = Path("output/fst_levers_keyresults")
PNG = RES / "_png"; PNG.mkdir(parents=True, exist_ok=True)
OUT = RES / "fst_levers_briefing_deck.pptx"

FONT = "Helvetica"
SLIDE_W, SLIDE_H = Inches(13.333), Inches(7.5)
TITLE_C, BODY_C, SUBTLE = RGBColor(0x1F,0x1F,0x1F), RGBColor(0x33,0x33,0x33), RGBColor(0x70,0x70,0x70)
ACCENT, GOOD = RGBColor(0x00,0x72,0xB2), RGBColor(0x4C,0x9F,0x70)

def rows(n):
    with open(RES / n) as f: return list(csv.DictReader(f))
def fmt(x, nd=0):
    x = float(x); return f"{x:,.4f}" if abs(x) < 1 else f"{x:,.{nd}f}"

feas  = rows("scenario_design.csv")
n_all, n_bad = len(feas), sum(1 for r in feas if r["feasible"] != "TRUE")
pb = {(r["outcome"], r["bio"]): float(r["prot_effect"]) for r in rows("protection_vs_bioenergy.csv")}
ero = {oc: (abs(pb[(oc,"off")]) - abs(pb[(oc,"on")])) / abs(pb[(oc,"off")]) * 100
       for oc in {k[0] for k in pb} if pb[(oc,"off")]}
def mdelta(f):
    a = {}
    for r in rows(f):
        if r["delta"] in ("","NA"): continue
        arm = ("1.5C" if r["cp"]=="on" else "NPi") + ("/Bio+" if r["bio"]=="on" else "/Bio-")
        a.setdefault((r["outcome"],arm),[]).append(float(r["delta"]))
    return {k: sum(v)/len(v) for k,v in a.items()}
tc, diet = mdelta("tc_effect.csv"), mdelta("diet_effect.csv")
me = {(r["outcome"], r["lever"]): float(r["effect"]) for r in rows("main_effects.csv")}
lp = {(r["pool"], r["lever"]): float(r["effect"]) for r in rows("land_pool_effects.csv")}

CROP="Cropland (Mha)"; CO2="Total land CO2 (Mt CO2/yr)"
BIO="Terrestrial biodiversity (index)"; NSU="Cropland+pasture N surplus (Mt Nr/yr)"
CP="Climate policy (1.5C)"; PR="Protection bundle"; DI="Dietary shift"; BE="Bioenergy demand"

# ---- helpers ----------------------------------------------------------------
def png_for(pdf):
    o = PNG / pdf.stem
    subprocess.run(["pdftoppm","-png","-r","200","-singlefile",str(pdf),str(o)], check=True)
    return o.with_suffix(".png")
def sf(run, size, *, bold=False, color=BODY_C):
    run.font.name, run.font.size, run.font.bold, run.font.color.rgb = FONT, Pt(size), bold, color
def tbox(s, text, l, t, w, h, size, *, bold=False, color=BODY_C):
    tf = s.shapes.add_textbox(l,t,w,h).text_frame; tf.word_wrap = True
    for i, line in enumerate(text.split("\n")):
        p = tf.paragraphs[0] if i==0 else tf.add_paragraph()
        r = p.add_run(); r.text = line; sf(r, size, bold=bold, color=color)
def img_fit(s, img, *, top, left, mw, mh):
    with Image.open(img) as im: iw, ih = im.size
    if iw/ih > mw/mh: w, h = mw, Emu(int(mw*ih/iw))
    else:             h, w = mh, Emu(int(mh*iw/ih))
    s.shapes.add_picture(str(img), Emu(int(left+(mw-w)/2)), Emu(int(top+(mh-h)/2)), w, h)
def fig(prs, pdf, title, take):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    tbox(s, title, Inches(0.55), Inches(0.28), Inches(12.2), Inches(0.7), 24, bold=True, color=TITLE_C)
    img_fit(s, png_for(RES/pdf), top=Inches(1.05), left=Inches(0.55), mw=Inches(12.2), mh=Inches(5.4))
    tbox(s, take, Inches(0.55), Inches(6.62), Inches(12.2), Inches(0.7), 12.5, color=SUBTLE)
def bullets(prs, title, items, foot=None, size=17):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    tbox(s, title, Inches(0.55), Inches(0.45), Inches(12.2), Inches(0.85), 28, bold=True, color=TITLE_C)
    tf = s.shapes.add_textbox(Inches(0.75), Inches(1.55), Inches(11.8), Inches(4.9)).text_frame
    tf.word_wrap = True
    for i, b in enumerate(items):
        p = tf.paragraphs[0] if i==0 else tf.add_paragraph(); p.space_after = Pt(13)
        r = p.add_run(); r.text = "•  " + b; sf(r, size)
    if foot: tbox(s, foot, Inches(0.55), Inches(6.62), Inches(12.2), Inches(0.7), 12, color=SUBTLE)

# ---- deck -------------------------------------------------------------------
prs = Presentation(); prs.slide_width, prs.slide_height = SLIDE_W, SLIDE_H

s = prs.slides.add_slide(prs.slide_layouts[6])
tbox(s, "Which levers actually move the planetary boundaries?", Inches(0.8), Inches(2.0),
     Inches(11.7), Inches(1.2), 36, bold=True, color=TITLE_C)
tbox(s, "A five-lever MAgPIE experiment on the food-system transformation", Inches(0.8), Inches(3.3),
     Inches(11.7), Inches(0.6), 19, color=ACCENT)
tbox(s, "RIKEN-PIK Work Package 2  |  fst_levers  |  August 2026", Inches(0.8), Inches(4.1),
     Inches(11.7), Inches(0.6), 15, color=SUBTLE)

bullets(prs, "The question",
  ["A food-system transformation is usually discussed as a package: price carbon, protect land, shift diets, "
   "grow bioenergy, raise yields. Packages hide which part is doing the work, and where the parts fight each other.",
   "So we ran the levers separately. Five binary switches, each on and off, against a common backdrop: "
   "climate policy, 2nd-generation bioenergy demand, an ambitious land-and-water protection bundle, an "
   "EAT-Lancet dietary shift, and whether yield-raising technological change is available at all.",
   "We score every combination against four planetary boundaries: climate, land, biodiversity and nitrogen.",
   "Two questions drove it: how much does technological change really matter, and does protecting land "
   "collide with growing bioenergy on it?"])

bullets(prs, "How it was set up",
  [f"{n_all} model runs. Not every combination: bioenergy demand at 1.5C levels WITHOUT a carbon price is not a "
   "real scenario - the price and the demand come from the same energy-system run - so that corner is deliberately absent.",
   "Everything transitions on the same 2025 to 2050 schedule, and non-CO2 abatement follows each run's own carbon "
   "price rather than being pinned high. Otherwise the levers would not be comparably ambitious.",
   "'Technological change off' means yields frozen at their business-as-usual path, not zero progress.",
   f"{n_all - n_bad} runs solved. The {n_bad} that did not are the headline result, not a technical footnote."],
  "All figures are at 2100 unless the axis says otherwise.")

fig(prs, "01_feasibility.pdf", "Result 1: four runs have no solution at all",
    "And they are one corner: a 1.5C carbon price plus bioenergy demand, with yields frozen. It fails whether or not "
    "land is protected, and whether or not diets shift. Neither freeing land nor cutting food demand rescues it.")

bullets(prs, "Why that matters more than it looks",
  ["An infeasible run is not a missing data point. It is the model saying there is no way to satisfy these "
   "constraints simultaneously.",
   "So technological change is not one lever among five. Under 1.5C with bioenergy, it is a precondition: without "
   "it the rest of the package has no solution, no matter how the other levers are set.",
   "This also means the bioenergy effect cannot be measured at frozen yields at all - every comparison that would "
   "require it passes through a corner that does not exist.",
   "The practical reading: yield growth is the enabling condition that lets climate policy and bioenergy coexist "
   "on the same land base."])

fig(prs, "04_tc_isolation.pdf", "Result 2: what technological change buys depends entirely on ambition",
    f"Under 1.5C it saves {fmt(abs(tc[(CROP,'1.5C/Bio-')]))} Mha of cropland and "
    f"{fmt(abs(tc[(CO2,'1.5C/Bio-')]))} Mt CO2/yr. Under current policy it does essentially nothing "
    f"({fmt(tc[(CROP,'NPi/Bio-')])} Mha). Yield growth is worth little in a world that is not asking much of land.")

fig(prs, "07_protection_vs_bioenergy.pdf", "Result 3: bioenergy eats into what land protection delivers",
    f"With bioenergy demand present, protection's carbon benefit falls {ero[CO2]:.0f}%, its biodiversity benefit "
    f"{ero[BIO]:.0f}%, its cropland benefit {ero[CROP]:.0f}% - but its nitrogen benefit only {ero[NSU]:.0f}%. "
    "The collision is specifically about land carbon, not about pollution.")

fig(prs, "08_main_effects.pdf", "Result 4: climate policy is the biggest lever on every boundary",
    f"Cropland: climate policy {fmt(me[(CROP,CP)])} Mha, dietary shift {fmt(me[(CROP,DI)])}, protection "
    f"{fmt(me[(CROP,PR)])}. Bioenergy is the only lever that moves every boundary the wrong way "
    f"({fmt(me[(CROP,BE)])} Mha of cropland). Green = helps, red = hurts.")

fig(prs, "12_where_levers_move_land.pdf",
    "Why climate policy beats protection even on biodiversity",
    f"Not because it moves more land - protection moves MORE pasture ({fmt(lp[('Pasture',PR)])} vs "
    f"{fmt(lp[('Pasture',CP)])} Mha). It moves land somewhere better: climate policy converts cropland to forest, "
    f"protection converts pasture to non-forest natural land, a smaller step up the naturalness gradient.")

bullets(prs, "The storyline in four sentences",
  ["Yield-raising technological change is the enabling condition for a 1.5C food system: without it, climate "
   "policy plus bioenergy has no feasible solution at all.",
   "Its value is entirely contingent on ambition - large under 1.5C, negligible under current policy - so it is "
   "a complement to climate policy, not a substitute for it.",
   "Ambitious land protection and bioenergy genuinely compete, and they compete over land carbon specifically: "
   f"protection's carbon benefit drops {ero[CO2]:.0f}% when bioenergy is in play, its nitrogen benefit barely at all.",
   "Carbon pricing is the largest lever on all four boundaries, including biodiversity - because it drives the "
   "high-value land conversion (cropland to forest) rather than the low-value one (pasture to scrub)."])

bullets(prs, "What we would flag to a reader",
  ["The biodiversity result is metric-dependent. Our index rewards forest cover. A biodiversity measure that "
   "valued grassland and savanna ecosystems would likely rank the protection bundle far higher - the levers move "
   "genuinely different ecosystems, not more or less of the same one.",
   "'Protection' here is four instruments moving together (area conservation, a biodiversity target, "
   "semi-natural vegetation on cropland, environmental flows), on top of existing protected areas and avoided "
   "deforestation that stay on in every run. It is the INCREMENT, not the total.",
   "Bioenergy's effect is measured only with climate policy on, and climate's only at baseline bioenergy - a "
   "consequence of leaving out the incoherent corner. Neither is a marginal effect over the whole design.",
   "Nothing here is a cost-benefit statement. We report physical outcomes and one food price index, not welfare."],
  "Next: per-region views; a sensitivity on the biodiversity metric; reconciling the two nitrogen definitions across iterations.")

prs.save(OUT)
print(f"wrote {OUT}  ({len(prs.slides._sldIdLst)} slides)")
