#!/usr/bin/env python3
"""Preseed a fresh classic-flat singleplayer world for the autoplay proof.

Writes <saves>/<world>/level.dat (deterministic: seed 0, creative,
classic flat, no structures touched) after deleting any previous copy, so
every automated run proves from scratch. Refuses loudly when the target
cannot be cleared. The client companion joins this world by folder name;
hub tools/verify-client-save.sh judges world == pure union afterwards
(decoration-free slices y=63..65: ground features never reach them).

1.12.2 shape (measured, not assumed): the legacy top-level generatorName
/ generatorOptions tags drive the terrain — unlike 1.16.5 there is no
WorldGenSettings to mirror (cf. bridge-1165 tools/autoplay/preseed.py,
which this file parallels per-version, never imports). generatorOptions
"2;7,2x3,2;1" is bedrock + 2 dirt + grass with no structure flag, so no
village piece can ever land in the proof slices; MapFeatures 0 doubles
that. DataVersion/version 1343 + Name 1.12.2 match the runtime, so the
client never migrates the save mid-proof.

Usage: preseed.py <saves-dir> <world-name>
"""
import gzip
import os
import shutil
import struct
import sys


def _tag(t, name, payload):
    return struct.pack(">b", t) + struct.pack(">h", len(name)) + name.encode() + payload


def _end():
    return struct.pack(">b", 0)


def _compound(name, body):
    return _tag(10, name, body + _end())


def _string(name, value):
    v = value.encode()
    return _tag(8, name, struct.pack(">h", len(v)) + v)


def _int(name, value):
    return _tag(3, name, struct.pack(">i", value))


def _long(name, value):
    return _tag(4, name, struct.pack(">q", value))


def _byte(name, value):
    return _tag(1, name, struct.pack(">b", value))


def main(saves, world):
    target = os.path.join(saves, world)
    if os.path.lexists(target):
        shutil.rmtree(target)
    os.makedirs(target)
    data = b"".join([
        _string("LevelName", world),
        _int("GameType", 1),
        _int("Difficulty", 1),
        _byte("allowCommands", 1),
        _long("Time", 0),
        _long("DayTime", 0),
        _int("SpawnX", 8),
        _int("SpawnY", 5),
        _int("SpawnZ", 8),
        _string("generatorName", "flat"),
        _string("generatorOptions", "2;7,2x3,2;1"),
        _int("generatorVersion", 0),
        _long("RandomSeed", 0),
        _byte("MapFeatures", 0),
        _byte("hardcore", 0),
        _int("version", 1343),
        _compound("Version", b"".join([
            _int("Id", 1343),
            _string("Name", "1.12.2"),
            _byte("Snapshot", 0),
        ])),
        _int("DataVersion", 1343),
        _byte("raining", 0),
        _byte("thundering", 0),
    ])
    root = _compound("", _compound("Data", data))
    with gzip.open(os.path.join(target, "level.dat"), "wb") as fh:
        fh.write(root)
    print("ok preseed : fresh flat <%s> (seed 0, creative)" % target)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("FAIL preseed : usage preseed.py <saves-dir> <world-name>")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
