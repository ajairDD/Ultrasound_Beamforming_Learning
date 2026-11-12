"""Audit original MATLAB figure labels against the reviewed Chinese map."""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALLOWED = set("DAS RTB FI RF IQ UFF USTB MATLAB CF GCF MVDR MV Capon EIBMV RCB DMAS fDMAS FWHM PSF SNR CNR gCNR ROI FFT DC MSE MAE RMSE Hann Hamming Tukey Tukey25 TheGB MHz Hz kHz GHz ns us ms mm cm dB rad NaN Inf true false BW fb eps diag trace cond sum abs real imag mean sqrt sign exp ones eye max min rank conj norm lambda delta rho mu theta pi Sigma Real Imaginary".split())
ALLOWED.update("Rx Tx fs fc f0 dz dx Nz Nx Npad M0 Re Im L7".split())
ALLOWED.difference_update({"Real","Imaginary"})
ALLOWED.difference_update({"real","imag","sum","abs","mean","min","max","sign","sqrt","exp","trace","diag","cond","rank","conj","norm","ones","eye"})
ALLOWED.update({"cos","sin"})

def load_map():
    path = ROOT / "tools/pdf/figure_translations.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    return {x["source"]: x["target"] for x in data["exact"]}, data.get("patterns", [])

def translate(text, exact, patterns):
    if text in exact:
        return exact[text]
    for entry in patterns:
        replacement = re.sub(r"\$(\d+)", r"\\g<\1>", entry["target"])
        text = re.sub(entry["source"], replacement, text)
    return text

def remaining_words(text):
    # LaTeX commands and numerical scientific notation are not English prose.
    cleaned = re.sub(r"\\[A-Za-z]+", "", text)
    cleaned = re.sub(r"\b[a-zA-Z]\w*\.[a-zA-Z]\w*\b", "", cleaned)
    cleaned = re.sub(r"\b(?:real|imag|sum|abs|mean|min|max|sign|sqrt|exp|trace|diag|cond|rank|conj|norm|ones|eye)\s*(?=\()", "", cleaned)
    cleaned = re.sub(r"\d(?:\.\d+)?[eE][+-]?\d+", "", cleaned)
    return [w for w in re.findall(r"[A-Za-z][A-Za-z_0-9]*", cleaned)
            if len(w)>1 and w not in ALLOWED and "_" not in w
            and not re.fullmatch(r"[A-Za-z]\d+",w)]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()
    exact, patterns = load_map()
    labels = {}
    files = list((ROOT/"work/pdfs/matlab_figures").rglob("*.texts.json"))
    for path in files:
        for original in json.loads(path.read_text(encoding="utf-8")):
            translated = translate(original,exact,patterns)
            unknown = remaining_words(translated)
            if unknown or args.all:
                labels[original] = {"source":original,"target":translated,"remaining":unknown}
    records = [labels[k] for k in sorted(labels)]
    target = ROOT/"work/pdfs/remaining_figure_text.json"
    target.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding="utf-8")
    for record in records:
        print(record["source"])
    print(f"FIGURES={len(files)}; UNRESOLVED_LABELS={len(records)}")

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
