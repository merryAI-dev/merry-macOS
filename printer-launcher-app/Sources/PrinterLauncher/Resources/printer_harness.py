#!/usr/bin/env python3
from __future__ import annotations

import argparse
import gzip
import json
import plistlib
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


LPADMIN = "/usr/sbin/lpadmin"
LPOPTIONS = "/usr/bin/lpoptions"
LP = "/usr/bin/lp"
LPSTAT = "/usr/bin/lpstat"

DEFAULT_QUEUE_NAME = "Canon_iR-ADV_DX_C3826"
DEFAULT_PRINTER_INFO = "Canon iR-ADV DX C3826"
DEFAULT_PPD_CANDIDATES = (
    Path("/Library/Printers/PPDs/Contents/Resources/CNPZUIRAC3826ZU.ppd.gz"),
    Path("/Library/Printers/PPDs/Contents/Resources/CNPZUIRAC3926ZU.ppd.gz"),
)

GLOBAL_PRESETS_PLIST = Path.home() / "Library/Preferences/com.apple.print.custompresets.plist"
QUEUE_PRESET_TEMPLATE = "com.apple.print.custompresets.forprinter.{queue}.plist"

SAFE_PRESET_KEYS = {
    "BindEdge",
    "CNAuthenticate",
    "CNDuplex",
    "CNEnableTrustPrint",
    "CNJobAccount",
    "CNJobExecMode",
    "CNPlatformVersion",
    "CNTrustPrint",
    "CNUseJobAccount",
    "CNUseUsrManagement",
    "CNUsrManagement",
    "CNUsrName",
    "CNUsrPassword",
    "Duplex",
    "InputSlot",
    "MediaType",
    "OutputBin",
    "Resolution",
    "sides",
}

GENERIC_DUPLEX_MAP = {
    "long-edge": "two-sided-long-edge",
    "short-edge": "two-sided-short-edge",
    "one-sided": "one-sided",
}

CANON_DUPLEX_MAP = {
    "long-edge": "DuplexFront",
    "short-edge": "DuplexFront",
    "one-sided": "None",
}


class HarnessError(RuntimeError):
    pass


@dataclass(frozen=True)
class Preset:
    source_id: str
    label: str
    settings: dict[str, str]


@dataclass(frozen=True)
class CommandStep:
    argv: list[str]
    requires_admin: bool = False


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Canon iR-ADV C3826 duplex harness built on top of the existing macOS "
            "Canon driver and CUPS commands."
        )
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    inspect_parser = subparsers.add_parser(
        "inspect-preset",
        help="Show reusable settings found in existing macOS print presets.",
    )
    add_printer_identity_args(inspect_parser, require_uri=False)
    inspect_parser.add_argument(
        "--preset-source",
        default="auto",
        choices=["auto", "none", "queue-last-used", "global-recent", "global-vendor-default", "global-default"],
        help="Which stored preset source to inspect.",
    )
    inspect_parser.add_argument(
        "--all-options",
        action="store_true",
        help="Show all valid PPD options from the preset instead of the safe subset.",
    )

    install_parser = subparsers.add_parser(
        "install",
        help="Create the printer queue and set duplex defaults.",
    )
    add_printer_identity_args(install_parser, require_uri=True)
    add_common_option_args(install_parser)
    install_parser.add_argument(
        "--sudo",
        action="store_true",
        help="Prefix the lpadmin step with sudo. Needed on most macOS systems.",
    )

    print_parser = subparsers.add_parser(
        "print",
        help="Submit a job with duplex defaults and any reusable auth settings.",
    )
    add_printer_identity_args(print_parser, require_uri=False)
    add_common_option_args(print_parser)
    print_parser.add_argument("file", type=Path, help="PDF or document to print.")
    print_parser.add_argument("--copies", type=int, default=1, help="Number of copies.")

    status_parser = subparsers.add_parser(
        "status",
        help="Show CUPS queue status.",
    )
    add_printer_identity_args(status_parser, require_uri=False)

    return parser.parse_args(argv)


def add_printer_identity_args(parser: argparse.ArgumentParser, require_uri: bool) -> None:
    parser.add_argument(
        "--queue-name",
        default=DEFAULT_QUEUE_NAME,
        help=f"Printer queue name. Default: {DEFAULT_QUEUE_NAME}",
    )
    parser.add_argument(
        "--ppd",
        type=Path,
        default=None,
        help="Path to the Canon PPD. Defaults to the installed C3826 Canon PPD if present.",
    )
    if require_uri:
        parser.add_argument(
            "--printer-uri",
            required=True,
            help="Printer URI such as ipp://<printer-ip>/ipp/print",
        )
    else:
        parser.add_argument(
            "--printer-uri",
            help="Optional printer URI. Only needed for install.",
        )


def add_common_option_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--preset-source",
        default="auto",
        choices=["auto", "none", "queue-last-used", "global-recent", "global-vendor-default", "global-default"],
        help="Which stored preset source to reuse.",
    )
    parser.add_argument(
        "--duplex",
        default="long-edge",
        choices=["long-edge", "short-edge", "one-sided"],
        help="Duplex mode to enforce.",
    )
    parser.add_argument(
        "--printer-info",
        default=DEFAULT_PRINTER_INFO,
        help=f"Friendly printer name. Default: {DEFAULT_PRINTER_INFO}",
    )
    parser.add_argument(
        "--location",
        default="",
        help="Optional printer location string stored in the queue.",
    )
    parser.add_argument(
        "--option",
        action="append",
        default=[],
        metavar="KEY=VALUE",
        help="Additional CUPS/PPD option to append. Can be passed multiple times.",
    )
    parser.add_argument(
        "--apply-all-preset-options",
        action="store_true",
        help="Apply every preset option that exists in the PPD, not just the safe subset.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the generated shell commands without executing them.",
    )


def discover_ppd_path(explicit_path: Path | None, preset: Preset | None = None) -> Path:
    if explicit_path:
        if not explicit_path.exists():
            raise HarnessError(f"PPD not found: {explicit_path}")
        return explicit_path

    if preset:
        ppd_id = preset.settings.get("CNPDECALL")
        if ppd_id:
            candidate = Path("/Library/Printers/PPDs/Contents/Resources") / f"{ppd_id}.ppd.gz"
            if candidate.exists():
                return candidate

    for candidate in DEFAULT_PPD_CANDIDATES:
        if candidate.exists():
            return candidate

    searched = ", ".join(str(path) for path in DEFAULT_PPD_CANDIDATES)
    raise HarnessError(f"No installed Canon PPD found. Checked: {searched}")


def parse_ppd_option_names(ppd_path: Path) -> set[str]:
    option_names: set[str] = set()
    with gzip.open(ppd_path, "rt", encoding="latin-1", errors="ignore") as handle:
        for line in handle:
            match = re.match(r"^\*OpenUI \*([^/\s:]+)", line)
            if match:
                option_names.add(match.group(1))
    return option_names


def load_plist(path: Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        data = plistlib.load(handle)
    if not isinstance(data, dict):
        raise HarnessError(f"Unexpected plist payload in {path}")
    return data


def queue_preset_plist(queue_name: str) -> Path:
    return Path.home() / "Library/Preferences" / QUEUE_PRESET_TEMPLATE.format(queue=queue_name)


def discover_presets(queue_name: str) -> list[Preset]:
    presets: list[Preset] = []

    queue_plist = queue_preset_plist(queue_name)
    if queue_plist.exists():
        queue_data = load_plist(queue_plist)
        settings = queue_data.get("com.apple.print.v2.lastUsedSettingsPref")
        if isinstance(settings, dict):
            presets.append(
                Preset(
                    source_id="queue-last-used",
                    label=f"{queue_name} last used settings",
                    settings=normalize_settings(settings),
                )
            )

    if GLOBAL_PRESETS_PLIST.exists():
        global_data = load_plist(GLOBAL_PRESETS_PLIST)
        mapping = [
            ("global-recent", "최근 사용한 설정", "Global recent settings"),
            ("global-vendor-default", "vendorDefaultSettings", "Vendor default settings"),
            ("global-default", "기본 설정", "Global default settings"),
        ]
        for source_id, raw_key, label in mapping:
            node = global_data.get(raw_key)
            if not isinstance(node, dict):
                continue
            settings = node.get("com.apple.print.preset.settings")
            if isinstance(settings, dict):
                presets.append(
                    Preset(
                        source_id=source_id,
                        label=label,
                        settings=normalize_settings(settings),
                    )
                )

    return presets


def normalize_settings(settings: dict[str, Any]) -> dict[str, str]:
    normalized: dict[str, str] = {}
    for key, value in settings.items():
        if value is None:
            continue
        if isinstance(value, bool):
            normalized[key] = "True" if value else "False"
            continue
        normalized[key] = str(value)
    return normalized


def resolve_preset(queue_name: str, source_id: str) -> Preset | None:
    if source_id == "none":
        return None

    presets = discover_presets(queue_name)
    if source_id == "auto":
        return presets[0] if presets else None

    for preset in presets:
        if preset.source_id == source_id:
            return preset
    return None


def filter_preset_options(
    settings: dict[str, str],
    valid_ppd_options: set[str],
    *,
    safe_only: bool,
) -> dict[str, str]:
    allowed = SAFE_PRESET_KEYS if safe_only else None
    filtered: dict[str, str] = {}
    for key, value in settings.items():
        if key not in valid_ppd_options and key not in SAFE_PRESET_KEYS and key != "sides":
            continue
        if allowed is not None and key not in allowed:
            continue
        filtered[key] = value
    return filtered


def duplex_options(mode: str) -> dict[str, str]:
    return {
        "CNDuplex": CANON_DUPLEX_MAP[mode],
        "sides": GENERIC_DUPLEX_MAP[mode],
    }


def parse_key_value_options(raw_options: list[str]) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for item in raw_options:
        if "=" not in item:
            raise HarnessError(f"Invalid --option value: {item}. Expected KEY=VALUE.")
        key, value = item.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            raise HarnessError(f"Invalid --option value: {item}. Empty key.")
        parsed[key] = value
    return parsed


def merge_options(*option_sets: dict[str, str]) -> dict[str, str]:
    merged: dict[str, str] = {}
    for option_set in option_sets:
        for key, value in option_set.items():
            merged[key] = value
    return merged


def build_install_steps(
    *,
    queue_name: str,
    printer_uri: str,
    printer_info: str,
    location: str,
    ppd_path: Path,
    options: dict[str, str],
) -> list[CommandStep]:
    lpadmin_argv = [
        LPADMIN,
        "-p",
        queue_name,
        "-E",
        "-v",
        printer_uri,
        "-P",
        str(ppd_path),
        "-D",
        printer_info,
    ]
    if location:
        lpadmin_argv.extend(["-L", location])

    lpoptions_argv = [LPOPTIONS, "-p", queue_name]
    lpoptions_argv.extend(flatten_option_args(options))

    return [
        CommandStep(lpadmin_argv, requires_admin=True),
        CommandStep(lpoptions_argv, requires_admin=False),
    ]


def build_print_step(
    *,
    queue_name: str,
    file_path: Path,
    copies: int,
    options: dict[str, str],
) -> CommandStep:
    argv = [LP, "-d", queue_name, "-n", str(copies)]
    argv.extend(flatten_option_args(options))
    argv.append(str(file_path))
    return CommandStep(argv, requires_admin=False)


def build_status_step(queue_name: str) -> CommandStep:
    return CommandStep([LPSTAT, "-p", queue_name, "-l"], requires_admin=False)


def flatten_option_args(options: dict[str, str]) -> list[str]:
    args: list[str] = []
    for key in sorted(options):
        args.extend(["-o", f"{key}={options[key]}"])
    return args


def execute_steps(steps: list[CommandStep], *, use_sudo: bool, dry_run: bool) -> int:
    for step in steps:
        argv = with_optional_sudo(step.argv, step.requires_admin and use_sudo)
        if dry_run:
            print(shell_join(argv))
            continue

        completed = subprocess.run(argv, check=False, text=True)
        if completed.returncode != 0:
            return completed.returncode
    return 0


def with_optional_sudo(argv: list[str], use_sudo: bool) -> list[str]:
    if use_sudo:
        return ["sudo", *argv]
    return argv


def shell_join(argv: list[str]) -> str:
    return " ".join(shlex.quote(part) for part in argv)


def command_inspect_preset(args: argparse.Namespace) -> int:
    preset = resolve_preset(args.queue_name, args.preset_source)
    ppd_path = discover_ppd_path(args.ppd, preset)
    valid_ppd_options = parse_ppd_option_names(ppd_path)

    payload = {
        "queue_name": args.queue_name,
        "ppd_path": str(ppd_path),
        "preset_found": preset is not None,
        "preset_source": preset.source_id if preset else None,
        "preset_label": preset.label if preset else None,
        "options": (
            filter_preset_options(
                preset.settings,
                valid_ppd_options,
                safe_only=not args.all_options,
            )
            if preset
            else {}
        ),
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


def command_install(args: argparse.Namespace) -> int:
    preset = resolve_preset(args.queue_name, args.preset_source)
    ppd_path = discover_ppd_path(args.ppd, preset)
    valid_ppd_options = parse_ppd_option_names(ppd_path)
    preset_options = (
        filter_preset_options(
            preset.settings,
            valid_ppd_options,
            safe_only=not args.apply_all_preset_options,
        )
        if preset
        else {}
    )
    options = merge_options(
        preset_options,
        duplex_options(args.duplex),
        parse_key_value_options(args.option),
    )
    steps = build_install_steps(
        queue_name=args.queue_name,
        printer_uri=args.printer_uri,
        printer_info=args.printer_info,
        location=args.location,
        ppd_path=ppd_path,
        options=options,
    )
    return execute_steps(steps, use_sudo=args.sudo, dry_run=args.dry_run)


def command_print(args: argparse.Namespace) -> int:
    if not args.file.exists():
        raise HarnessError(f"File not found: {args.file}")

    preset = resolve_preset(args.queue_name, args.preset_source)
    ppd_path = discover_ppd_path(args.ppd, preset)
    valid_ppd_options = parse_ppd_option_names(ppd_path)
    preset_options = (
        filter_preset_options(
            preset.settings,
            valid_ppd_options,
            safe_only=not args.apply_all_preset_options,
        )
        if preset
        else {}
    )
    options = merge_options(
        preset_options,
        duplex_options(args.duplex),
        parse_key_value_options(args.option),
    )
    step = build_print_step(
        queue_name=args.queue_name,
        file_path=args.file,
        copies=args.copies,
        options=options,
    )
    return execute_steps([step], use_sudo=False, dry_run=args.dry_run)


def command_status(args: argparse.Namespace) -> int:
    completed = subprocess.run(
        build_status_step(args.queue_name).argv,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode == 0:
        if completed.stdout:
            print(completed.stdout, end="")
        return 0

    combined = "\n".join(part for part in (completed.stdout, completed.stderr) if part).strip()
    if "유효하지 않은 대상 이름" in combined or "Unknown destination" in combined:
        print(
            f"Queue {args.queue_name} is not installed yet. Run the install command first.",
            file=sys.stderr,
        )
        return 1

    if combined:
        print(combined, file=sys.stderr)
    return completed.returncode


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        if args.command == "inspect-preset":
            return command_inspect_preset(args)
        if args.command == "install":
            return command_install(args)
        if args.command == "print":
            return command_print(args)
        if args.command == "status":
            return command_status(args)
        raise HarnessError(f"Unsupported command: {args.command}")
    except HarnessError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
