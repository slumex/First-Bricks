#!/usr/bin/env python3
"""Ajoute un inventaire CFB synthétique >17 Mio à une instance locale de test."""
import base64
import hashlib
import http.client
import os
import re
import uuid
from xml.etree import ElementTree as ET
from pathlib import Path

host = "127.0.0.1"
port = int(os.environ.get("SMOKE_PORT", "4000"))
auth = "Basic " + base64.b64encode((os.environ["SMOKE_USERNAME"] + ":" + os.environ["SMOKE_PASSWORD"]).encode()).decode()
cookies = ""
def request(method, path, body=None, content_type=None):
    global cookies
    connection = http.client.HTTPConnection(host, port, timeout=180)
    headers = {"Authorization": auth}
    if cookies:
        headers["Cookie"] = cookies
    if content_type:
        headers["Content-Type"] = content_type
    connection.request(method, path, body, headers)
    response = connection.getresponse()
    data = response.read()
    if response.getheader("Set-Cookie"):
        cookies = response.getheader("Set-Cookie").split(";", 1)[0]
    result = response.status, data
    connection.close()
    return result

status, body = request("GET", "/")
assert status == 200
assert b"data-max-bytes='50000000'" in body
assert request("GET", "/js/uploads.js")[0] == 200
token = re.search(rb"name='_csrf_token' value='([^']+)'", body).group(1).decode()
source = ET.parse(Path(__file__).resolve().parents[1] / "examples/inventaire-cfb.bsx")
item = ET.tostring(source.find("./Inventory/Item"), encoding="unicode")
rows = "".join(item.replace("<ItemID>3001</ItemID>", f"<ItemID>large-{i}</ItemID>") for i in range(90_000))
xml = ("<?xml version='1.0' encoding='UTF-8'?><BrickStoreXML><Inventory>" + rows + "</Inventory></BrickStoreXML>").encode()
assert len(xml) > 17 * 1024 * 1024
boundary = uuid.uuid4().hex
body = b"".join([
    f'--{boundary}\r\nContent-Disposition: form-data; name="kind"\r\n\r\ncfb\r\n'.encode(),
    f'--{boundary}\r\nContent-Disposition: form-data; name="_csrf_token"\r\n\r\n{token}\r\n'.encode(),
    f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="large-synthetic.bsx"\r\nContent-Type: application/xml\r\n\r\n'.encode(),
    xml, f'\r\n--{boundary}--\r\n'.encode()
])
status, body = request("POST", "/imports", body, "multipart/form-data; boundary=" + boundary)
assert status == 302, (status, body[:300])
status, body = request("GET", "/")
assert status == 200 and b"90000 lots" in body
path = re.search(rb"href='(/inventories/cfb/[^']+)'", body).group(1).decode()
status, original = request("GET", path)
assert status == 200 and hashlib.sha256(original).digest() == hashlib.sha256(xml).digest()
print(f"Import HTTP et conservation de l'original : {len(xml):,} octets, 90 000 lots, OK.")
