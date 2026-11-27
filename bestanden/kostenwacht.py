"""Kostenwacht voor Goose: een kleine lokale doorgeefluik naar api.anthropic.com.

- Laat alleen de toegelaten modellen toe (Haiku en Sonnet); andere Haiku/Sonnet-namen worden omgezet.
- Telt per dag het verbruik (tokens x officiele prijs) en weigert nieuwe vragen boven de daglimiet.
- Luistert alleen op 127.0.0.1. Bewaart geen sleutels en geen inhoud van gesprekken, enkel tellers.
Alleen standaardbibliotheek. Start: pythonw kostenwacht.py <instellingen.json>
"""
import datetime
import http.client
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# USD per 1 miljoen tokens: input, output, cache schrijven (5 min), cache lezen
PRIJZEN = {
    "claude-haiku-5-5": (0.10, 0.50, 0.125, 0.01),
    "claude-sonnet-5-5": (2.00, 10.00, 2.50, 0.10),
}
UPSTREAM = "api.anthropic.com"

INST = json.load(open(sys.argv[1], encoding="utf-8"))
MAP = os.path.dirname(os.path.abspath(sys.argv[1]))
VERBRUIK = os.path.join(MAP, "verbruik.json")
LIMIET_USD = float(INST["limietEurPerDag"]) * float(INST["usdPerEur"])
TOEGELATEN = list(INST["toegelatenModellen"])
LOCK = threading.Lock()


def vandaag():
    return datetime.date.today().isoformat()


def lees():
    try:
        with open(VERBRUIK, encoding="utf-8") as f:
            d = json.load(f)
    except Exception:
        d = {}
    if d.get("datum") != vandaag():
        d = {"datum": vandaag(), "usd": 0.0, "vragen": 0, "perModel": {}}
    return d


def bewaar(d):
    tmp = VERBRUIK + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=1)
    os.replace(tmp, VERBRUIK)


def boek(model, usage):
    p = PRIJZEN.get(model)
    if not p:
        return
    kost = (usage.get("input_tokens", 0) * p[0] + usage.get("output_tokens", 0) * p[1]
            + usage.get("cache_creation_input_tokens", 0) * p[2]
            + usage.get("cache_read_input_tokens", 0) * p[3]) / 1e6
    with LOCK:
        d = lees()
        d["usd"] = round(d["usd"] + kost, 6)
        d["vragen"] += 1
        d["perModel"][model] = round(d["perModel"].get(model, 0.0) + kost, 6)
        bewaar(d)


def kies_model(gevraagd):
    """Geeft het toegelaten model terug, of None als het geweigerd wordt."""
    if gevraagd in TOEGELATEN:
        return gevraagd
    g = (gevraagd or "").lower()
    for m in TOEGELATEN:
        familie = m.split("-")[1]  # haiku / sonnet
        if familie in g:
            return m
    return None


def eur(usd):
    return usd / float(INST["usdPerEur"])


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def fout(self, code, soort, tekst):
        body = json.dumps({"type": "error", "error": {"type": soort, "message": tekst}}).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/verbruik":
            with LOCK:
                d = lees()
            d["limietEur"] = float(INST["limietEurPerDag"])
            d["verbruiktEur"] = round(eur(d["usd"]), 4)
            body = json.dumps(d, indent=1).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.doorsturen(None)

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else b""
        model = None
        if self.path.split("?")[0].endswith("/messages"):
            try:
                data = json.loads(body)
            except Exception:
                return self.fout(400, "invalid_request_error", "Ongeldige aanvraag.")
            model = kies_model(data.get("model"))
            if not model:
                return self.fout(400, "invalid_request_error",
                                 f"Model {data.get('model')} is niet toegelaten. Kies {' of '.join(TOEGELATEN)}.")
            with LOCK:
                d = lees()
            if d["usd"] >= LIMIET_USD:
                return self.fout(400, "invalid_request_error",
                                 f"Daglimiet bereikt: vandaag is al EUR {eur(d['usd']):.2f} van de EUR "
                                 f"{float(INST['limietEurPerDag']):.2f} verbruikt. Morgen kan je weer verder.")
            if data.get("model") != model:
                data["model"] = model
                body = json.dumps(data).encode()
        self.doorsturen(body, model)

    def doorsturen(self, body, model=None):
        conn = http.client.HTTPSConnection(UPSTREAM, timeout=600)
        hdrs = {k: v for k, v in self.headers.items()
                if k.lower() not in ("host", "content-length", "connection", "accept-encoding")}
        if body is not None:
            hdrs["Content-Length"] = str(len(body))
        try:
            conn.request(self.command, self.path, body=body, headers=hdrs)
            r = conn.getresponse()
        except Exception as e:
            return self.fout(502, "api_error", f"Anthropic is niet bereikbaar: {e}")
        ctype = r.getheader("Content-Type", "")
        stream = "text/event-stream" in ctype
        self.send_response(r.status)
        for k, v in r.getheaders():
            if k.lower() not in ("transfer-encoding", "content-length", "connection", "content-encoding"):
                self.send_header(k, v)
        usage = {}
        if stream:
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            buf = b""
            while True:
                chunk = r.read1(65536)
                if not chunk:
                    break
                self.wfile.write(b"%x\r\n%s\r\n" % (len(chunk), chunk))
                self.wfile.flush()
                buf += chunk
                while b"\n" in buf:
                    regel, buf = buf.split(b"\n", 1)
                    if regel.startswith(b"data:") and model:
                        try:
                            ev = json.loads(regel[5:])
                        except Exception:
                            continue
                        u = (ev.get("message") or {}).get("usage") or ev.get("usage") or {}
                        for k, v in u.items():
                            if isinstance(v, int):
                                usage[k] = max(usage.get(k, 0), v)
            self.wfile.write(b"0\r\n\r\n")
        else:
            data = r.read()
            # /v1/models: toon alleen de toegelaten modellen
            if self.path.split("?")[0].endswith("/models") and r.status == 200:
                try:
                    j = json.loads(data)
                    j["data"] = [m for m in j.get("data", []) if m.get("id") in TOEGELATEN]
                    data = json.dumps(j).encode()
                except Exception:
                    pass
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            if model:
                try:
                    usage = {k: v for k, v in (json.loads(data).get("usage") or {}).items() if isinstance(v, int)}
                except Exception:
                    usage = {}
        conn.close()
        if model and usage:
            boek(model, usage)


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("127.0.0.1", int(INST["wachtPoort"])), Handler)
    srv.daemon_threads = True
    srv.serve_forever()
