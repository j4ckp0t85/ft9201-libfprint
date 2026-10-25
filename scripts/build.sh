#!/usr/bin/env bash
# Build the libfprint tree tracked in this repo with the FT9201 driver.
# src/ is the source of truth: the driver files are copied into libfprint/ and
# the driver is registered in its meson config before compiling.
set -euo pipefail
cd "$(dirname "$0")/.."

LFP=libfprint

[ -f src/ft9201_fw.h ] || { echo "!! missing src/ft9201_fw.h"; exit 1; }
[ -f blobs/ftWbioEngineAdapter.dll ] || { echo "!! missing blobs/ftWbioEngineAdapter.dll"; exit 1; }

[ -d "$LFP" ] || { echo "!! missing $LFP/ tree"; exit 1; }

echo "==> installing driver files into the tree"
cp src/ft9201.c src/ft_engine.c src/ft_engine.h src/ft9201_fw.h "$LFP/libfprint/drivers/"

echo "==> registering the driver in meson"
python3 - "$LFP/libfprint/meson.build" <<'PY'
import sys
f = sys.argv[1]; s = open(f).read()
if "'ft9201'" not in s:
    s = s.replace("driver_sources = {",
                  "driver_sources = {\n    'ft9201' : [ 'drivers/ft9201.c', 'drivers/ft_engine.c' ],", 1)
    open(f, "w").write(s)
    print("    injected ft9201 into driver_sources")
else:
    print("    ft9201 already present")
PY

echo "==> configuring + building (only the ft9201 driver)"
RECONF=""; [ -d "$LFP/build" ] && RECONF="--reconfigure"
meson setup "$LFP/build" "$LFP" $RECONF \
    -Ddrivers=ft9201 -Dgtk-examples=false -Ddoc=false -Dintrospection=false >/dev/null
ninja -C "$LFP/build" libfprint/libfprint-2.so.2.0.0 examples/enroll examples/verify

echo
echo "Built: $LFP/build/libfprint/libfprint-2.so.2.0.0"
echo "Test without installing:"
echo "  FT9201_ENGINE_DLL=\$PWD/blobs/ftWbioEngineAdapter.dll \\"
echo "  LD_LIBRARY_PATH=$LFP/build/libfprint $LFP/build/examples/enroll"
echo "Or install for KDE/login:  sudo scripts/install.sh"
