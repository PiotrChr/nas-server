#!/usr/bin/env python3
"""
Bootstrap the NAS/nomad environment by installing prerequisites, generating
inventory/vars, and staging Nomad jobs selected by the user.
"""
from __future__ import annotations

import json
import os
import platform
import shlex
import shutil
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = REPO_ROOT / ".nas-setup.json"
INVENTORY_PATH = REPO_ROOT / "ansible" / "inventory" / "hosts"
GENERATED_VARS_PATH = REPO_ROOT / "ansible" / "group_vars" / "generated.yml"
DEFAULTS_PATH = REPO_ROOT / "ansible" / "roles" / "nomad" / "defaults" / "main.yml"
JOBS_SOURCE_DIR = REPO_ROOT / "nomad" / "jobs"
SERVER_JOBS_DIR = REPO_ROOT / "server" / "nomad-jobs"
VENV_PATH = REPO_ROOT / ".venv"
REQUIREMENTS_PATH = REPO_ROOT / "requirements.txt"


def bootstrap_entry() -> None:
    ensure_local_virtualenv()
    main()


def ensure_local_virtualenv() -> None:
    if os.environ.get("NAS_BOOTSTRAP_SKIP_VENV") == "1":
        return
    if not REQUIREMENTS_PATH.exists():
        return
    if in_virtualenv():
        return

    print("==> Preparing local Python environment in .venv")
    if not VENV_PATH.exists():
        VENV_PATH.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([sys.executable, "-m", "venv", str(VENV_PATH)], check=True)

    pip_exe = venv_executable("pip")
    subprocess.run([pip_exe, "install", "--upgrade", "pip"], check=True)
    subprocess.run([pip_exe, "install", "-r", str(REQUIREMENTS_PATH)], check=True)

    python_exe = venv_executable("python")
    env = os.environ.copy()
    env["NAS_BOOTSTRAP_SKIP_VENV"] = "1"
    subprocess.run(
        [python_exe, str(Path(__file__).resolve()), *sys.argv[1:]],
        check=True,
        env=env,
    )
    sys.exit(0)


def in_virtualenv() -> bool:
    return sys.prefix != getattr(sys, "base_prefix", sys.prefix)


def venv_executable(name: str) -> str:
    folder = "Scripts" if os.name == "nt" else "bin"
    return str(VENV_PATH / folder / name)


def main() -> None:
    print("==> NAS bootstrap starting")
    state = load_state()
    yaml_mod = ensure_yaml_module()
    ensure_dependencies()
    connection = configure_connection(state)
    if prompt_bool("Upload this SSH key to the remote host now?", default=True):
        push_public_key(connection)
    write_inventory(connection)
    volumes = configure_volumes(state.get("nomad_host_volumes"), yaml_mod)
    services = choose_services(state.get("nomad_enabled_jobs"))
    sync_nomad_jobs(services)
    write_generated_vars(volumes, services, yaml_mod)
    state.update(
        {
            "inventory_name": connection["inventory_name"],
            "ansible_host": connection["host"],
            "ansible_user": connection["user"],
            "ansible_port": connection["port"],
            "ssh_key": str(connection["ssh_key"]),
            "nomad_host_volumes": volumes,
            "nomad_enabled_jobs": services,
        }
    )
    save_state(state)
    print("\nAll set! You can now run `ansible-playbook -i ansible/inventory/hosts ansible/site.yml`.")


def load_state() -> Dict[str, Any]:
    if CONFIG_PATH.exists():
        with CONFIG_PATH.open() as fh:
            return json.load(fh)
    return {}


def save_state(state: Dict[str, Any]) -> None:
    with CONFIG_PATH.open("w") as fh:
        json.dump(state, fh, indent=2)


def ensure_yaml_module():
    try:
        import yaml  # type: ignore
    except ModuleNotFoundError:
        print("PyYAML missing, installing required Python packages…")
        install_python_requirements()
        import yaml  # type: ignore
    return yaml


def install_python_requirements() -> None:
    if REQUIREMENTS_PATH.exists():
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "-r", str(REQUIREMENTS_PATH)],
            check=True,
        )
    else:
        subprocess.run([sys.executable, "-m", "pip", "install", "PyYAML"], check=True)


def ensure_dependencies() -> None:
    system = platform.system()
    print(f"Detected host OS: {system}")
    if system == "Darwin":
        ensure_homebrew()
        ensure_binary("ansible-playbook", lambda: brew_install("ansible"))
        ensure_binary("nomad", lambda: brew_install("nomad"))
    elif system == "Linux":
        pkg_manager = detect_package_manager()
        if pkg_manager == "apt":
            ensure_binary("ansible-playbook", lambda: apt_install(["ansible"]))
            ensure_binary("nomad", lambda: apt_install(["nomad"]))
        elif pkg_manager in {"dnf", "yum"}:
            ensure_binary("ansible-playbook", lambda: rpm_install(pkg_manager, ["ansible"]))
            ensure_binary("nomad", lambda: rpm_install(pkg_manager, ["nomad"]))
        else:
            print("No supported package manager found. Please install Ansible and Nomad manually.")
    else:
        print("Unsupported OS for automatic dependency install. Please ensure Ansible and Nomad are installed.")


def ensure_homebrew() -> None:
    if shutil.which("brew"):
        return
    print("Homebrew is required to install dependencies on macOS. Install it from https://brew.sh/ and rerun.")
    sys.exit(1)


def ensure_binary(binary: str, installer) -> None:
    if shutil.which(binary):
        return
    print(f"{binary} not found. Installing…")
    try:
        installer()
    except subprocess.CalledProcessError as exc:
        print(f"Failed to install {binary}: {exc}")
        sys.exit(exc.returncode)


def brew_install(package: str) -> None:
    subprocess.run(["brew", "install", package], check=True)


_APT_UPDATED = False


def apt_install(packages: List[str]) -> None:
    global _APT_UPDATED
    if not _APT_UPDATED:
        subprocess.run(["sudo", "apt-get", "update"], check=True)
        _APT_UPDATED = True
    subprocess.run(["sudo", "apt-get", "install", "-y"] + packages, check=True)


def rpm_install(manager: str, packages: List[str]) -> None:
    subprocess.run(["sudo", manager, "install", "-y"] + packages, check=True)


def detect_package_manager() -> Optional[str]:
    for candidate in ("apt", "dnf", "yum"):
        if shutil.which(candidate):
            return candidate
    return None


def configure_connection(state: Dict[str, Any]) -> Dict[str, Any]:
    print("\n==> Connection details")
    inventory_name = prompt(
        "Inventory host alias",
        default=state.get("inventory_name", "nas"),
    )
    host = prompt(
        "Remote server IP or hostname",
        default=state.get("ansible_host", "192.168.1.50"),
    )
    user = prompt("Ansible SSH user", default=state.get("ansible_user", "ansible"))
    port = prompt_int("SSH port", default=state.get("ansible_port", 22))
    ssh_key = ensure_ssh_key(Path(state.get("ssh_key", "~/.ssh/nas-server")).expanduser())
    return {
        "inventory_name": inventory_name,
        "host": host,
        "user": user,
        "port": port,
        "ssh_key": ssh_key,
    }


def ensure_ssh_key(path: Path) -> Path:
    path = path.expanduser()
    if path.exists():
        return path
    if not prompt_bool(f"SSH key {path} does not exist. Create it?", default=True):
        print("Cannot continue without an SSH key.")
        sys.exit(1)
    path.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ssh-keygen", "-t", "ed25519", "-f", str(path), "-N", ""]
    subprocess.run(cmd, check=True)
    return path


def push_public_key(connection: Dict[str, Any]) -> None:
    pub = Path(f"{connection['ssh_key']}.pub")
    if not pub.exists():
        print(f"Public key {pub} missing. Re-run ssh-keygen.")
        return
    host = f"{connection['user']}@{connection['host']}"
    port = connection["port"]
    if shutil.which("ssh-copy-id"):
        cmd = ["ssh-copy-id", "-i", str(pub)]
        if port != 22:
            cmd.extend(["-p", str(port)])
        cmd.append(host)
    else:
        authorized = (
            "mkdir -p ~/.ssh && chmod 700 ~/.ssh && "
            f'echo {shlex.quote(pub.read_text().strip())} >> ~/.ssh/authorized_keys && '
            "chmod 600 ~/.ssh/authorized_keys"
        )
        cmd = ["ssh"]
        if port != 22:
            cmd.extend(["-p", str(port)])
        cmd.extend([host, authorized])
    print("Uploading SSH public key…")
    subprocess.run(cmd, check=True)


def write_inventory(connection: Dict[str, Any]) -> None:
    INVENTORY_PATH.parent.mkdir(parents=True, exist_ok=True)
    key_display = shrink_home(connection["ssh_key"])
    lines = [
        "# Generated by scripts/bootstrap.py",
        "[nas]",
        (
            f"{connection['inventory_name']} "
            f"ansible_host={connection['host']} "
            f"ansible_user={connection['user']} "
            f"ansible_port={connection['port']} "
            f"ansible_ssh_private_key_file={key_display}"
        ),
        "",
    ]
    INVENTORY_PATH.write_text("\n".join(lines))
    print(f"Wrote inventory to {INVENTORY_PATH}")


def shrink_home(path: Path) -> str:
    path = path.expanduser()
    home = Path.home()
    try:
        return f"~/{path.relative_to(home)}"
    except ValueError:
        return str(path)


def configure_volumes(existing: Optional[List[Dict[str, Any]]], yaml_mod) -> List[Dict[str, Any]]:
    print("\n==> Nomad host volumes")
    base = existing or load_default_volumes(yaml_mod)
    configured: List[Dict[str, Any]] = []
    for volume in base:
        entry = prompt_volume(volume, allow_skip=True)
        if entry:
            configured.append(entry)
    while prompt_bool("Add another host volume?", default=False):
        name = prompt("  Volume name")
        entry = prompt_volume({"name": name}, allow_skip=False)
        if entry:
            configured.append(entry)
    return configured


def load_default_volumes(yaml_mod) -> List[Dict[str, Any]]:
    data = yaml_mod.safe_load(DEFAULTS_PATH.read_text())
    volumes = data.get("nomad_host_volumes", [])
    return volumes if isinstance(volumes, list) else []


def prompt_volume(volume: Dict[str, Any], allow_skip: bool) -> Optional[Dict[str, Any]]:
    name = prompt("  Volume name", default=volume.get("name"))
    if allow_skip and not prompt_bool(f"  Keep '{name}'?", default=True):
        return None
    path = prompt("    Host path", default=volume.get("path"))
    read_only = prompt_bool("    Read only?", default=volume.get("read_only", False))
    ensure_dir = prompt_bool("    Create directory if missing?", default=volume.get("ensure", True))
    recurse = prompt_bool("    Recurse when setting ownership?", default=volume.get("recurse", True))
    owner = prompt_optional("    Owner UID/GID (blank to skip)", volume.get("owner"))
    group = prompt_optional("    Group UID/GID (blank to skip)", volume.get("group"))
    mode = prompt_optional("    Directory mode (default 0755)", volume.get("mode"))
    entry: Dict[str, Any] = OrderedDict()
    entry["name"] = name
    entry["path"] = path
    entry["read_only"] = bool(read_only)
    entry["ensure"] = bool(ensure_dir)
    entry["recurse"] = bool(recurse)
    if owner:
        entry["owner"] = owner
    if group:
        entry["group"] = group
    if mode:
        entry["mode"] = mode
    return entry


def choose_services(existing: Optional[List[str]]) -> List[str]:
    print("\n==> Nomad services")
    available = sorted(job.stem for job in JOBS_SOURCE_DIR.glob("*.nomad.hcl"))
    if not available:
        print("No job files found under nomad/jobs.")
        return []
    print("Available services:")
    for idx, name in enumerate(available, start=1):
        marker = "*" if existing and name in existing else " "
        print(f"  {idx:2}) {name}{marker}")
    default_hint = ",".join(existing) if existing else "all"
    while True:
        raw = input(f"Select services (comma names, 'all', or leave blank for {default_hint}): ").strip()
        if not raw:
            return available if not existing else existing
        if raw.lower() == "all":
            return available
        if raw.lower() in {"none", "skip"}:
            return []
        choices = {item.strip() for item in raw.replace(" ", ",").split(",") if item.strip()}
        unknown = choices - set(available)
        if unknown:
            print(f"Unknown services: {', '.join(sorted(unknown))}")
            continue
        return [name for name in available if name in choices]


def sync_nomad_jobs(services: List[str]) -> None:
    SERVER_JOBS_DIR.mkdir(parents=True, exist_ok=True)
    for job_path in SERVER_JOBS_DIR.glob("*.nomad.hcl"):
        if job_path.stem not in services:
            job_path.unlink()
    for service in services:
        src = JOBS_SOURCE_DIR / f"{service}.nomad.hcl"
        dest = SERVER_JOBS_DIR / f"{service}.nomad.hcl"
        if not src.exists():
            print(f"WARNING: {src} missing, skipping.")
            continue
        shutil.copy2(src, dest)
    if services:
        print(f"Staged {len(services)} Nomad job(s) in {SERVER_JOBS_DIR}")
    else:
        print("No services selected; cleared server/nomad-jobs.")


def write_generated_vars(volumes: List[Dict[str, Any]], services: List[str], yaml_mod) -> None:
    GENERATED_VARS_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "nomad_host_volumes": volumes,
        "nomad_enabled_jobs": services,
    }
    content = "# Generated by scripts/bootstrap.py\n" + yaml_mod.safe_dump(
        payload, sort_keys=False, default_flow_style=False
    )
    GENERATED_VARS_PATH.write_text(content)
    print(f"Wrote generated vars to {GENERATED_VARS_PATH}")


def prompt(message: str, default: Optional[Any] = None) -> str:
    while True:
        suffix = f" [{default}]" if default not in (None, "") else ""
        value = input(f"{message}{suffix}: ").strip()
        if not value and default not in (None, ""):
            return str(default)
        if value:
            return value
        print("  Value required.")


def prompt_optional(message: str, default: Optional[Any] = None) -> Optional[str]:
    suffix = f" [{default}]" if default not in (None, "") else ""
    value = input(f"{message}{suffix}: ").strip()
    return value or default


def prompt_bool(message: str, default: bool = False) -> bool:
    suffix = " [Y/n]" if default else " [y/N]"
    while True:
        value = input(f"{message}{suffix}: ").strip().lower()
        if not value:
            return default
        if value in {"y", "yes"}:
            return True
        if value in {"n", "no"}:
            return False
        print("  Please answer yes or no.")


def prompt_int(message: str, default: int) -> int:
    while True:
        value = input(f"{message} [{default}]: ").strip()
        if not value:
            return default
        if value.isdigit():
            return int(value)
        print("  Enter a valid integer.")


if __name__ == "__main__":
    try:
        bootstrap_entry()
    except KeyboardInterrupt:
        print("\nAborted.")
        sys.exit(1)
