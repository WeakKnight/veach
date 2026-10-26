# Generates tests/fixtures/aces2-reference.json with OpenColorIO's ACES 2.0 implementation
# (the ACES reference implementation for GPUs/CPUs), used to validate src/render/aces.
#   python -m pip install opencolorio
#   python scripts/aces2-reference.py
import json
import os
import random

import PyOpenColorIO as OCIO

config = OCIO.Config.CreateFromBuiltinConfig('studio-config-latest')
VIEW = 'ACES 2.0 - SDR 100 nits (Rec.709)'
DISPLAY = 'sRGB - Display'


def processor(src):
    return config.getProcessor(src, DISPLAY, VIEW, OCIO.TRANSFORM_DIR_FORWARD).getDefaultCPUProcessor()


def apply(cpu, rgb):
    return list(cpu.applyRGB(list(rgb)))


random.seed(1234)
inputs = [[0.0, 0.0, 0.0]]
for v in [1e-4, 1e-3, 0.01, 0.05, 0.18, 0.5, 1.0, 2.0, 5.0, 10.0, 50.0, 100.0, 1000.0]:
    inputs.append([v, v, v])
for scale in [0.05, 0.18, 1.0, 4.0, 16.0, 100.0]:
    for c in [[1, 0, 0], [0, 1, 0], [0, 0, 1], [1, 1, 0], [0, 1, 1], [1, 0, 1], [1, 0.5, 0.1], [0.1, 0.3, 1.0]]:
        inputs.append([scale * x for x in c])
for _ in range(400):
    inputs.append([10 ** random.uniform(-4, 2) if random.random() > 0.1 else 0.0 for _ in range(3)])

aces = processor('ACES2065-1')
rec709 = processor('Linear Rec.709 (sRGB)')
to_ap0 = config.getProcessor('Linear Rec.709 (sRGB)', 'ACES2065-1').getDefaultCPUProcessor()
rec709_to_ap0 = [list(to_ap0.applyRGB([1.0 if i == j else 0.0 for j in range(3)])) for i in range(3)]

out = {
    'ocio': OCIO.__version__,
    'view': VIEW,
    'display': DISPLAY,
    'rec709ToAP0Columns': rec709_to_ap0,
    'aces2065': [{'in': x, 'out': apply(aces, x)} for x in inputs],
    'linearRec709': [{'in': x, 'out': apply(rec709, x)} for x in inputs],
}
path = os.path.join(os.path.dirname(__file__), '..', 'tests', 'fixtures', 'aces2-reference.json')
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f:
    json.dump(out, f, indent=None, separators=(',', ':'))
print('wrote', os.path.normpath(path), len(inputs), 'samples')
