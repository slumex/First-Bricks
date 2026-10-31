#!/usr/bin/env python3
"""Parcours HTTP réel, sans dépendance Python externe; voir README.
Les identifiants sont lus dans SMOKE_USERNAME et SMOKE_PASSWORD.
"""
import argparse
import base64
import http.client
import json
import os
import re
import urllib.parse
import uuid
import xml.etree.ElementTree as ET
from http.cookies import SimpleCookie
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--base-url", default="http://127.0.0.1:4000")
parser.add_argument("--state", default="/tmp/first-bricks-smoke.json")
parser.add_argument("--check-state", action="store_true")
args = parser.parse_args()
url = urllib.parse.urlsplit(args.base_url)
if url.scheme not in ("http", "https"):
    raise SystemExit("URL HTTP(S) attendue")
if url.scheme == "http" and url.hostname not in ("127.0.0.1", "localhost"):
    raise SystemExit("HTTPS requis hors machine locale")
credentials = os.environ["SMOKE_USERNAME"] + ":" + os.environ["SMOKE_PASSWORD"]
authorization = "Basic " + base64.b64encode(credentials.encode()).decode()
cookies = {}


def request(method, path, body=None, content_type=None, authenticated=True, forwarded=True):
    cls = http.client.HTTPSConnection if url.scheme == "https" else http.client.HTTPConnection
    connection = cls(url.hostname, url.port, timeout=30)
    headers = {}
    if authenticated:
        headers["Authorization"] = authorization
    if cookies:
        headers["Cookie"] = "; ".join(k + "=" + v for k, v in cookies.items())
    if forwarded and os.environ.get("SMOKE_FORWARDED_PROTO"):
        if url.hostname not in ("127.0.0.1", "localhost"):
            raise SystemExit("Simulation du proxy réservée au test local")
        headers["X-Forwarded-Proto"] = os.environ["SMOKE_FORWARDED_PROTO"]
    if content_type:
        headers["Content-Type"] = content_type
    connection.request(method, path, body=body, headers=headers)
    response = connection.getresponse()
    data = response.read()
    for name, value in response.getheaders():
        if name.lower() == "set-cookie":
            parsed = SimpleCookie()
            parsed.load(value)
            cookies.update({k: v.value for k, v in parsed.items()})
    result = (response.status, dict(response.getheaders()), data)
    connection.close()
    return result


def csrf(body):
    return re.search(rb"name='_csrf_token' value='([^']+)'", body).group(1).decode()


def post_form(path, data):
    return request("POST", path, urllib.parse.urlencode(data), "application/x-www-form-urlencoded")


def check_exports(path):
    expected = {"cfb": {"3001": 5, "3020": 1}, "ufb": {"3001": 5, "3002": 4, "3020": 2}}
    for site in ("cfb", "ufb"):
        export_path = path + "/exports/" + site
        status, headers, body = request("GET", export_path)
        assert status == 200, (status, body[:100])
        assert ".bsx" in headers["content-disposition"]
        document = ET.fromstring(body)
        quantities = {i.findtext("ItemID"): int(i.findtext("Qty")) for i in document.findall("./Inventory/Item")}
        assert quantities == expected[site], quantities
        assert request("GET", export_path, authenticated=False)[0] == 401


if os.environ.get("SMOKE_FORWARDED_PROTO"):
    assert request("GET", "/health", authenticated=False, forwarded=False)[0] == 200
    status, headers, _ = request("GET", "/", authenticated=False, forwarded=False)
    assert status == 301 and headers["location"].startswith("https://"), (status, headers)
assert request("GET", "/health", authenticated=False)[0] == 200
assert request("GET", "/", authenticated=False)[0] == 401
if args.check_state:
    saved = json.loads(Path(args.state).read_text())
    path = saved["reception"]
    assert request("GET", path)[0] == 200
    check_exports(path)
    for original_path, expected_xml in saved["originals"]:
        status, _, body = request("GET", original_path)
        assert status == 200 and body.decode() == expected_xml
    print("Persistance après redémarrage : réception, répartitions, deux inventaires originaux et exports OK.")
else:
    status, _, body = request("GET", "/")
    assert status == 200
    token = csrf(body)
    assert post_form("/imports", {"kind": "vendor"})[0] == 403
    root = Path(__file__).resolve().parents[1]
    for kind, filename in (("cfb", "inventaire-cfb.bsx"), ("ufb", "inventaire-ufb.bsx"), ("vendor", "reception-vendor.bsx")):
        boundary = uuid.uuid4().hex
        chunks = []
        for key, value in (("kind", kind), ("_csrf_token", token)):
            chunks.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
        chunks.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\nContent-Type: application/xml\r\n\r\n'.encode())
        chunks.append((root / "examples" / filename).read_bytes())
        chunks.append(f'\r\n--{boundary}--\r\n'.encode())
        status, headers, body = request("POST", "/imports", b"".join(chunks), "multipart/form-data; boundary=" + boundary)
        assert status == 302, (status, body[:200])
        path = headers["location"]
    status, _, body = request("GET", path)
    assert status == 200
    assert "Présent · 0" in body.decode() and "Absent" in body.decode()
    token = csrf(body)
    revision = re.search(rb'name="revision" value="(\d+)"', body).group(1).decode()
    fields = {"_csrf_token": token, "revision": revision,
              "cfb[0]": "5", "cfb[1]": "0", "cfb[2]": "1",
              "ufb[0]": "5", "ufb[1]": "4", "ufb[2]": "2"}
    assert post_form(path, fields)[0] == 302
    assert post_form(path, fields)[0] == 422  # Révision périmée.
    fields["revision"] = "1"
    fields["cfb[0]"] = "11"
    assert post_form(path, fields)[0] == 422  # Dépassement sans écriture.
    check_exports(path)
    status, _, body = request("GET", "/")
    assert status == 200
    original_paths = re.findall(r"href='(/inventories/(cfb|ufb)/[^']+)'", body.decode())
    originals = []
    for original_path, site in original_paths:
        status, _, original = request("GET", original_path)
        assert status == 200
        expected = (root / "examples" / ("inventaire-" + site + ".bsx")).read_text()
        assert original.decode() == expected
        originals.append((original_path, expected))
    assert len(originals) >= 2
    Path(args.state).write_text(json.dumps({"reception": path, "originals": originals}))
    print("HTTP réel : auth, CSRF, 3 imports, absent/zéro, sauvegarde, conflit, dépassement, originaux et 2 exports OK.")
