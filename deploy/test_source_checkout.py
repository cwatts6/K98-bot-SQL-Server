"""Offline checkout custody regression; no SQL, network or primary-index writes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parents[1]
    def git(*args, env=None):
        return subprocess.check_output(["git", *args], cwd=repo, env=env)

    head = git("rev-parse", "HEAD").decode().strip()
    path = "deploy/recovery/s11_withdraw_405_20261008/withdraw.sql"
    historical = git("show", head + ":" + path)
    with tempfile.TemporaryDirectory(prefix="k98-source-checkout-") as directory:
        temporary = Path(directory)
        checkout = temporary / "checkout"
        checkout.mkdir()
        env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        env["GIT_INDEX_FILE"] = str(temporary / "index")
        env["GIT_WORK_TREE"] = str(checkout)
        git("read-tree", head, env=env)
        git("-c", "core.autocrlf=false", "checkout-index", "--all",
            "--prefix=" + checkout.as_posix() + "/", env=env)
        actual = (checkout / path).read_bytes()
        if actual != historical:
            raise AssertionError("Historical evidence bytes changed on checkout")
        # Force status to inspect content instead of trusting freshly cached stat data.
        # A clean first status alone can hide normalization errors in committed blobs.
        for file in checkout.rglob("*"):
            if file.is_file():
                stat = file.stat()
                os.utime(file, ns=(stat.st_atime_ns, stat.st_mtime_ns + 5_000_000_000))
        status = git("--no-optional-locks", "-c", "core.autocrlf=false",
                     "status", "--porcelain", "--untracked-files=normal", env=env)
        if status.strip():
            raise AssertionError("Checkout is not clean after content recheck: " + status.decode())
        print(json.dumps({"status": "PASS", "head": head,
                          "historical_sha256": hashlib.sha256(actual).hexdigest(),
                          "sql_executed": False}))


if __name__ == "__main__":
    main()
