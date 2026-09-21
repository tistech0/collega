#!/usr/bin/env python3
"""Vérification réelle de l'upload par morceaux (Story 7.11) — via LAN ou via Cloudflare (--cloudflare-ip).

Enchaîne init → PUT parts → complete avec curl, affiche le code HTTP et le temps par morceau.
Relancé avec `--resume <upload_id>`, ne renvoie que les morceaux manquants (lus via `status`).

Exemple :
  .venv/bin/python scripts/chunked_upload.py "../CANCERO 4e college (1).pdf" --ref-id 3 \\
      --email jerome@collega.fr --password '…' --cloudflare-ip 172.67.211.66 --env-file ../collega_app/.env.local
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HOST = "collegatest.matthislesur.com"
BASE = f"https://{HOST}"


def curl(args: list[str], extra: list[str]) -> tuple[int, str]:
    out = subprocess.run(
        ["curl", "-s", "-o", "/dev/stdout", "-w", "\n__HTTP %{http_code}", *extra, *args],
        capture_output=True,
        text=True,
    ).stdout
    body, _, code = out.rpartition("\n__HTTP ")
    return int(code or 0), body


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("pdf")
    p.add_argument("--ref-id", type=int, required=True)
    p.add_argument("--email", required=True)
    p.add_argument("--password", required=True)
    p.add_argument("--base-url", default=BASE, help=f"défaut : {BASE}")
    p.add_argument("--cloudflare-ip", help="force la résolution DNS vers cette IP (chemin public Cloudflare)")
    p.add_argument("--env-file", help="fichier .env contenant CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET")
    p.add_argument("--resume", help="upload_id à reprendre (seuls les morceaux manquants sont envoyés)")
    a = p.parse_args()
    base = a.base_url.rstrip("/")

    extra: list[str] = []
    if a.cloudflare_ip:
        extra += ["--resolve", f"{HOST}:443:{a.cloudflare_ip}"]
    if a.env_file:
        env = dict(line.strip().split("=", 1) for line in open(a.env_file) if "=" in line)
        extra += [
            "-H", f"CF-Access-Client-Id: {env['CF_ACCESS_CLIENT_ID']}",
            "-H", f"CF-Access-Client-Secret: {env['CF_ACCESS_CLIENT_SECRET']}",
        ]

    code, body = curl(
        ["-X", "POST", f"{base}/v1/auth/login", "-H", "Content-Type: application/json",
         "-d", json.dumps({"email": a.email, "password": a.password})],
        extra,
    )
    if code != 200:
        print("login", code, body[:200])
        return 1
    tok = json.loads(body)["data"]["access_token"]
    auth = ["-H", f"Authorization: Bearer {tok}"]

    pdf = Path(a.pdf)
    size = pdf.stat().st_size
    if a.resume:
        code, body = curl([f"{base}/v1/colleges/import/{a.resume}"], extra)
        print("status", code, body[:200])
        if code != 200:
            return 1
        st = json.loads(body)["data"]
        upload_id = a.resume
    else:
        code, body = curl(
            ["-X", "POST", f"{base}/v1/colleges/{a.ref_id}/import/init", "-H", "Content-Type: application/json",
             "-d", json.dumps({"size_bytes": size}), *auth],
            extra,
        )
        print("init", code, body[:200])
        if code != 201:
            return 1
        st = json.loads(body)["data"]
        upload_id = st["upload_id"]
        st["received"] = []
    part_size, total = st["part_size"], st["parts_total"]
    print(f"upload_id={upload_id} parts={total} size={size}")

    t0 = time.time()
    with open(pdf, "rb") as f, tempfile.TemporaryDirectory() as tmpdir:
        for n in range(total):
            if n in st["received"]:
                print(f"part {n}/{total - 1}: déjà reçu, ignoré")
                continue
            f.seek(n * part_size)
            data = f.read(part_size)
            tmp = Path(tmpdir) / f"part_{n}"
            tmp.write_bytes(data)
            t = time.time()
            code, body = curl(
                ["-X", "PUT", f"{base}/v1/colleges/import/{upload_id}/parts/{n}",
                 "-H", "Content-Type: application/octet-stream", "--data-binary", f"@{tmp}"],
                extra,
            )
            tmp.unlink()
            print(f"part {n}/{total - 1}: HTTP {code} {len(data) / 2**20:.1f} MB in {time.time() - t:.1f}s")
            if code != 204:
                print(body[:200])
                print("→ stop ; reprendre avec --resume", upload_id)
                return 1

    t = time.time()
    code, body = curl(["-X", "POST", f"{base}/v1/colleges/import/{upload_id}/complete", *auth], extra)
    print(f"complete {code} in {time.time() - t:.1f}s (total {time.time() - t0:.0f}s)", body[:300])
    return 0 if code == 202 else 1


if __name__ == "__main__":
    sys.exit(main())
