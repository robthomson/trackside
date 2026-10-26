"""
Trackside simulator sensors.

A small window with sliders/switches for fake telemetry (link, battery, ESC).
Every change is written straight away to

    <sim root>/scripts/trackside.user/sim/sensors.lua

which the Lua side (lib/telemetry.lua) reads only when running in the Ethos
simulator. The file lives outside scripts/trackside/ so a deploy never deletes it.

The sim root is found the same way .vscode/scripts/deploy.py finds it:
    <repo>/simulators/<ethos.board>_<ethos.protocol>@<ethos.release>
from .vscode/settings.json. Use --dest to point somewhere else.

Usage:
    python bin/sensors/sensors.py [--dest <sim root or scripts folder>] [--xml <file>]
"""

import argparse
import json
import os
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

import tkinter as tk
from tkinter import ttk

REPO = Path(__file__).resolve().parents[2]
TARGET = "trackside"
OUT_REL = Path(f"{TARGET}.user") / "sim" / "sensors.lua"


def _load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def default_scripts_dir():
    """scripts/ folder of the simulator configured in .vscode/settings.json."""
    settings = _load_json(REPO / ".vscode" / "settings.json")
    board = settings.get("ethos.board")
    protocol = settings.get("ethos.protocol")
    release = settings.get("ethos.release")
    sims = settings.get("ethos.simulatorsFolder") or "simulators"
    if not (board and protocol):
        return None
    name = f"{board}_{protocol}" + (f"@{release}" if release else "")
    return REPO / sims / name / "scripts"


def resolve_scripts_dir(dest):
    if not dest:
        return default_scripts_dir()
    p = Path(dest).resolve()
    return p if p.name.lower() == "scripts" else p / "scripts"


def lua_number(v):
    if float(v).is_integer():
        return str(int(v))
    return f"{v:.3f}".rstrip("0").rstrip(".")


class SensorApp:
    def __init__(self, root, xml_path, scripts_dir):
        self.root = root
        self.out_path = scripts_dir / OUT_REL
        self.sensors = []      # (name, var, kind, extra)
        self._pending = None

        root.title("Trackside - simulator sensors")
        root.minsize(460, 0)

        tree = ET.parse(xml_path)
        for group in tree.getroot().findall("Group"):
            frame = ttk.LabelFrame(root, text=group.get("name"))
            frame.pack(fill="x", padx=10, pady=5)
            for sensor in group.findall("Sensor"):
                self._add_control(frame, sensor)

        bar = ttk.Frame(root)
        bar.pack(fill="x", padx=10, pady=(4, 8))
        ttk.Button(bar, text="Reset to defaults", command=self.reset).pack(side="left")
        self.status = tk.StringVar(value=f"Writing to {self.out_path}")
        ttk.Label(root, textvariable=self.status, foreground="#666").pack(fill="x", padx=10, pady=(0, 8))

        self.write()

    # --- controls ---------------------------------------------------------
    def _add_control(self, parent, el):
        name = el.get("name")
        label = el.get("label", name)
        kind = el.get("type", "range")
        unit = el.get("unit", "")
        default = float(el.get("default", 0))
        jitter = float(el.get("jitter", 0))

        row = ttk.Frame(parent)
        row.pack(fill="x", padx=6, pady=2)
        ttk.Label(row, text=label, width=16).pack(side="left")

        if kind == "range":
            lo, hi = float(el.get("min", 0)), float(el.get("max", 100))
            rounding = el.get("round") == "true"
            var = tk.DoubleVar(value=default)
            text = tk.StringVar()

            def show(*_):
                v = var.get()
                text.set(f"{int(round(v))}" if rounding else f"{v:.2f}")
            show()

            def on_move(_v, var=var, rnd=rounding):
                if rnd:
                    var.set(round(var.get()))
                show()
                self.schedule_write()

            ttk.Scale(row, from_=lo, to=hi, variable=var, orient="horizontal",
                      command=on_move).pack(side="left", fill="x", expand=True)

            entry = ttk.Entry(row, textvariable=text, width=8)
            entry.pack(side="left", padx=4)

            def on_entry(_e=None, var=var, text=text, lo=lo, hi=hi):
                try:
                    v = min(hi, max(lo, float(text.get())))
                    var.set(v)
                except ValueError:
                    pass
                show()
                self.schedule_write()
            entry.bind("<Return>", on_entry)
            entry.bind("<FocusOut>", on_entry)

            if unit:
                ttk.Label(row, text=unit, width=5).pack(side="left")
            self.sensors.append((name, var, "range", {"jitter": jitter, "default": default}))

        elif kind == "bool":
            var = tk.IntVar(value=1 if default else 0)
            ttk.Checkbutton(row, variable=var, command=self.schedule_write).pack(side="left")
            self.sensors.append((name, var, "bool", {"default": default}))

        elif kind == "select":
            options = [(o.get("label"), float(o.get("value"))) for o in el.findall("Option")]
            labels = [o[0] for o in options]
            by_label = dict(options)
            start = next((l for l, v in options if v == default), labels[0] if labels else "")
            var = tk.StringVar(value=start)
            box = ttk.Combobox(row, textvariable=var, values=labels, state="readonly", width=14)
            box.pack(side="left")
            box.bind("<<ComboboxSelected>>", lambda _e: self.schedule_write())
            self.sensors.append((name, var, "select", {"map": by_label, "default": start}))

    def value_of(self, kind, var, extra):
        if kind == "select":
            return extra["map"].get(var.get(), 0)
        return float(var.get())

    def reset(self):
        for name, var, kind, extra in self.sensors:
            var.set(extra["default"])
        self.write()

    # --- output -----------------------------------------------------------
    def schedule_write(self):
        # Coalesce slider drags into one write every 150 ms.
        if self._pending is None:
            self._pending = self.root.after(150, self.write)

    def write(self):
        self._pending = None
        lines = ["-- Written by bin/sensors/sensors.py. Simulator only.", "return {",
                 f"  stamp = {int(time.time())},"]
        for name, var, kind, extra in self.sensors:
            v = self.value_of(kind, var, extra)
            jitter = extra.get("jitter", 0) or 0
            if jitter:
                lines.append(f"  {name} = {{ value = {lua_number(v)}, jitter = {lua_number(jitter)} }},")
            else:
                lines.append(f"  {name} = {{ value = {lua_number(v)} }},")
        lines.append("}")
        text = "\n".join(lines) + "\n"
        try:
            self.out_path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.out_path.with_suffix(".tmp")
            with open(tmp, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
            os.replace(tmp, self.out_path)
            self.status.set(f"Updated {time.strftime('%H:%M:%S')}  ->  {self.out_path}")
        except Exception as e:
            self.status.set(f"Write failed: {e}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dest", help="Simulator root (or its scripts/ folder). Default: from .vscode/settings.json")
    ap.add_argument("--xml", default=str(Path(__file__).with_name("sensors.xml")), help="Sensor definitions")
    args = ap.parse_args()

    scripts_dir = resolve_scripts_dir(args.dest)
    if scripts_dir is None:
        print("[SENSORS] No simulator configured (.vscode/settings.json ethos.board / ethos.protocol). Use --dest.")
        return 1
    print(f"[SENSORS] Writing to {scripts_dir / OUT_REL}")

    root = tk.Tk()
    SensorApp(root, Path(args.xml), scripts_dir)
    root.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
