#!/usr/bin/env python3
"""Merge upstream APNs with a small device APN overlay and overrides."""

import argparse
import json
import sys
from pathlib import Path
from xml.etree import ElementTree as ET


def comparable(attributes):
    result = dict(attributes)
    if "type" in result:
        result["type"] = tuple(sorted(set(result["type"].split(","))))
    return tuple(sorted(result.items()))


def read_apns(path):
    root = ET.parse(path).getroot()
    if root.tag != "apns" or "version" not in root.attrib:
        raise ValueError(f"{path}: expected <apns version=\"...\">")
    rows = []
    for element in root:
        if element.tag != "apn" or len(element):
            raise ValueError(f"{path}: unexpected APN structure")
        rows.append(dict(element.attrib))
    return root.get("version"), rows


def matches(attributes, conditions):
    for key, value in conditions.items():
        if key == "type" and value is not None:
            actual = attributes.get(key)
            if actual is None or set(actual.split(",")) != set(value.split(",")):
                return False
        elif attributes.get(key) != value:
            return False
    return True


def serialize(version, rows):
    root = ET.Element("apns", {"version": version})
    for attributes in rows:
        ET.SubElement(root, "apn", {k: v.replace("\r", "&#13;") for k, v in attributes.items()})
    if len(root):
        root.text = "\n    "
        for element in root[:-1]:
            element.tail = "\n    "
        root[-1].tail = "\n"
    xml = ET.tostring(root, encoding="utf-8")
    xml = xml.replace(b"&amp;#13;", b"&#13;")
    return (
        b'<?xml version="1.0" encoding="utf-8"?>\n'
        b'<!--\n'
        b'    SPDX-FileCopyrightText: Google Inc\n'
        b'    SPDX-FileCopyrightText: The LineageOS Project\n'
        b'    SPDX-License-Identifier: Apache-2.0\n'
        b'-->\n' + xml + b"\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", required=True, type=Path)
    parser.add_argument("--overlay", required=True, type=Path)
    parser.add_argument("--overrides", required=True, type=Path)
    args = parser.parse_args()

    version, rows = read_apns(args.upstream)
    overlay_version, overlay_rows = read_apns(args.overlay)
    if overlay_version != version:
        raise ValueError(f"overlay version {overlay_version} != upstream {version}")

    overrides = json.loads(args.overrides.read_text(encoding="utf-8"))
    for rule in overrides:
        found = [i for i, attrs in enumerate(rows) if matches(attrs, rule["match"])]
        if not found:
            print(f"warning: override matched no upstream APN: {rule['match']}", file=sys.stderr)
            continue
        for i in found:
            rows[i].update(rule["set"])

    unique = {}
    for attrs in rows + overlay_rows:
        unique.setdefault(comparable(attrs), attrs)
    sys.stdout.buffer.write(serialize(version, list(unique.values())))


if __name__ == "__main__":
    main()
