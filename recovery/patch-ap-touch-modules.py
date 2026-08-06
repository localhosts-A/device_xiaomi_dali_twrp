#!/usr/bin/env python3
"""Stage Recovery-only kernel modules (AP touch fallback and vendor_dlkm flashlight/haptics chains) from OTA inputs."""

import hashlib
import os
import shutil
import stat
import struct
import sys
import tempfile
from pathlib import Path


ELF_HEADER = struct.Struct("<16sHHIQQQIHHHHHH")
SECTION_HEADER = struct.Struct("<IIQQQQIIQQ")
SYMBOL = struct.Struct("<IBBHQQ")
RELA = struct.Struct("<QQq")

ET_REL = 1
EM_AARCH64 = 183
SHT_SYMTAB = 2
SHT_RELA = 4
SHT_NOBITS = 8
STB_GLOBAL = 1
STT_FUNC = 2

SCP_SOURCE_SHA256 = "7dd0abf1bdcc804ac2ae077debc52c0646c163b80df505ca99e7713cce297db6"
SCP_OUTPUT_SHA256 = "e00d0d0a8892ffd07467e4dc38060b6ea901125e4e86f2d8e38fd7ef2a9ac0c4"
GOODIX_SOURCE_SHA256 = "d299c83cd2e334c22ae510de172146b39146cc4fdb1860fd1c67210a98cda156"
GOODIX_OUTPUT_SHA256 = "2015fd201a82913ef07b736ac3f35dcc89562cb92359e3d934ec98764219b3c0"
XIAOMI_TOUCH_SHA256 = "46a49015776c944612669a0c7d7d26d14dc28333e5ffbc8248f75ab0aa4d6e08"
FOCALTECH_SOURCE_SHA256 = "58ebffcce836b6a603cbd6ef23113b985a2638bcfc584a4b74cbb64ae126f17e"
FOCALTECH_OUTPUT_SHA256 = "f7c5c0dcde05c33a1b5764f974e782ecd89c9eb7e3dec1299734092e9311578d"
PLATFORM_DEP_SHA256 = "dd972abacb2c2cd5475903b8ad681c9985d0a3be67fd2e6f65c812305be8034c"

PACIASP = bytes.fromhex("3f2303d5")
AUTIASP = bytes.fromhex("bf2303d5")
RET = bytes.fromhex("c0035fd6")
MOV_W0_ZERO = bytes.fromhex("00008052")
MOV_W0_ONE = bytes.fromhex("20008052")

MODULE_SPECS = {
    "scp.ko": {
        "source_sha256": SCP_SOURCE_SHA256,
        "output_sha256": SCP_OUTPUT_SHA256,
        "size": 466112,
        "symbol": "init_module",
        "section": ".init.text",
        "section_index": 30,
        "value": 0x4,
        "symbol_size": 0x870,
        "file_offset": 0x2070C,
        "preimage": bytes.fromhex("3f2303d5fd7bbda9f65701a9f44f02a9"),
        "replacement": PACIASP + MOV_W0_ZERO + AUTIASP + RET,
        "changed_bytes": 12,
        "required_relocation": "scp_region_info_init",
    },
    "goodix_core_dali.ko": {
        "source_sha256": GOODIX_SOURCE_SHA256,
        "output_sha256": GOODIX_OUTPUT_SHA256,
        "size": 585144,
        "symbol": "scp_tp_init",
        "section": ".text",
        "section_index": 14,
        "value": 0x26854,
        "symbol_size": 0x174,
        "file_offset": 0x2A854,
        "preimage": bytes.fromhex("3f2303d5fd7bbea9f44f01a9fd030091"),
        "replacement": PACIASP + MOV_W0_ONE + AUTIASP + RET,
        "changed_bytes": 11,
        "required_relocation": None,
    },
    "focaltech_touch_dali.ko": {
        "source_sha256": FOCALTECH_SOURCE_SHA256,
        "output_sha256": FOCALTECH_OUTPUT_SHA256,
        "size": 771848,
        "symbol": "scp_tp_init",
        "section": ".text",
        "section_index": 14,
        "value": 0x32A24,
        "symbol_size": 0x174,
        "file_offset": 0x37A24,
        "preimage": bytes.fromhex("3f2303d5fd7bbea9f44f01a9"),
        "replacement": PACIASP + MOV_W0_ONE + AUTIASP + RET,
        "changed_bytes": 11,
        "required_relocation": None,
    },
}

COPY_SPECS = {
    "xiaomi_touch_dali.ko": (XIAOMI_TOUCH_SHA256, 211696),
    "flashlight.ko": ("6c0cd49e6b460831b5d77389168aab30ee83340c7f439ec1d36f67d076e7a425", 119224),
    "leds-mt6379.ko": ("3313b221d8b85e6f8c0c8dfbe53ef2434beea2fddb80d6c568e1f30aa1e8b893", 32944),
    "leds-mt6379pmic.ko": ("8cb39457b591a069bb00e63aab71525f7380a597f54e4b398d084cb852dd64d4", 38000),
    "mtk_gpueb.ko": ("a8e1387320581bb943b84ec544559b6373225819f319d7103088a3f44fa87db2", 126816),
    "mtk_pbm.ko": ("cb440df5ece567746a3beedcd42111e8edd20633c05347421e520fbba3254b29", 51136),
    "mtk_peak_power_budget.ko": ("da0402612a579b93ec12ac2bafae86a5118a17dfb4d2c04f177200074980520c", 132592),
    "cl_dsp-core.ko": ("3cc58bed32717df66f4dce569c25962630cb0a3b12bb2b7e0f07185309610a17", 117624),
    "cs40l26-core.ko": ("e222d9eda7897ea25368a4a55ce6b46032dfbf57a71eb3a259eebc67f563580f", 264464),
    "cs40l26-i2c.ko": ("f74fd302eec0b1f2383b1f603e647d2543c345c6ece0afc58c95ed2e907202b3", 16184),
    "cs40l26-spi.ko": ("a4781ab300e0f089beb78614e36594a23381dd41e8d12684c8b3cf3fc23c9990", 16184),
    "snd-soc-cs40l26.ko": ("0357ea716d99980c275fe2d4445690f51013a7d6e52ceb5d632fb027e14b2e21", 62048),
}

REQUIRED_PLATFORM_DEPENDENCIES = (
    "/lib/modules/tui-common.ko:",
    "/lib/modules/mtk_tinysys_ipi.ko: /lib/modules/mtk_rpmsg_mbox.ko /lib/modules/mtk-mbox.ko",
    "/lib/modules/mtk_rpmsg_mbox.ko: /lib/modules/mtk-mbox.ko",
    "/lib/modules/mtk-mbox.ko:",
)

RECOVERY_DEPENDENCIES = (
    "goodix_core_dali.ko: tui-common.ko xiaomi_touch_dali.ko scp.ko mtk_tinysys_ipi.ko mtk_rpmsg_mbox.ko mtk-mbox.ko",
    "focaltech_touch_dali.ko: tui-common.ko xiaomi_touch_dali.ko scp.ko mtk_tinysys_ipi.ko mtk_rpmsg_mbox.ko mtk-mbox.ko",
    "xiaomi_touch_dali.ko:",
    "scp.ko: mtk_tinysys_ipi.ko mtk_rpmsg_mbox.ko mtk-mbox.ko",
    "mtk_gpueb.ko: mtk_tinysys_ipi.ko mtk-mbox.ko",
    "mtk_pbm.ko: mtk_dynamic_loading_throttling.ko mtk_mdpm.ko",
    "mtk_peak_power_budget.ko: mtk_gpueb.ko mtk_tinysys_ipi.ko mtk_low_battery_throttling.ko mtk_bp_thl.ko",
    "flashlight.ko: mtk_pbm.ko mtk_peak_power_budget.ko mtk_low_battery_throttling.ko mtk_bp_thl.ko mtk_battery_oc_throttling.ko",
    "leds-mt6379.ko: v4l2-flash-led-class.ko flashlight.ko",
    "leds-mt6379pmic.ko: v4l2-flash-led-class.ko flashlight.ko",
    "cl_dsp-core.ko:",
    "cs40l26-core.ko: cl_dsp-core.ko miev.ko",
    "cs40l26-i2c.ko: cs40l26-core.ko",
    "cs40l26-spi.ko: cs40l26-core.ko",
    "snd-soc-cs40l26.ko: cs40l26-core.ko cl_dsp-core.ko",
)

PUBLISHED_FILES = tuple(MODULE_SPECS) + tuple(COPY_SPECS) + ("modules.dep",)


class ValidationError(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_regular(path):
    metadata = path.lstat()
    require(stat.S_ISREG(metadata.st_mode), f"input is not a regular file: {path}")
    require(not path.is_symlink(), f"input must not be a symlink: {path}")
    return path.read_bytes()


def read_c_string(table, offset, field):
    require(offset < len(table), f"invalid {field} string offset: {offset}")
    end = table.find(b"\0", offset)
    require(end != -1, f"unterminated {field} string")
    return table[offset:end].decode("ascii")


def parse_elf(data):
    require(len(data) >= ELF_HEADER.size, "ELF header is truncated")
    header = ELF_HEADER.unpack_from(data)
    ident, elf_type, machine, version, _, _, section_offset, _, header_size, _, _, section_size, section_count, section_name_index = header
    require(ident[:4] == b"\x7fELF", "invalid ELF magic")
    require(ident[4] == 2 and ident[5] == 1, "module is not ELF64 little-endian")
    require(elf_type == ET_REL and machine == EM_AARCH64 and version == 1, "unexpected ELF type or machine")
    require(header_size == ELF_HEADER.size, "unexpected ELF header size")
    require(section_size == SECTION_HEADER.size and section_count > 0, "unexpected section table")
    table_end = section_offset + section_size * section_count
    require(section_offset > 0 and table_end <= len(data), "section table is out of bounds")
    require(section_name_index < section_count, "invalid section-name table index")

    sections = []
    for index in range(section_count):
        values = SECTION_HEADER.unpack_from(data, section_offset + index * section_size)
        name_offset, kind, _, _, offset, size, link, info, _, entry_size = values
        if kind != SHT_NOBITS:
            require(offset + size <= len(data), f"section {index} is out of bounds")
        sections.append({
            "index": index,
            "name_offset": name_offset,
            "kind": kind,
            "offset": offset,
            "size": size,
            "link": link,
            "info": info,
            "entry_size": entry_size,
        })

    name_section = sections[section_name_index]
    require(name_section["kind"] != SHT_NOBITS, "section-name table has no bytes")
    names = data[name_section["offset"]:name_section["offset"] + name_section["size"]]
    for section in sections:
        section["name"] = read_c_string(names, section["name_offset"], "section")

    symbol_tables = {}
    for section in sections:
        if section["kind"] != SHT_SYMTAB:
            continue
        require(section["entry_size"] == SYMBOL.size, "unexpected symbol-table entry size")
        require(section["link"] < len(sections), "symbol table has invalid string-table link")
        strings_section = sections[section["link"]]
        require(strings_section["kind"] != SHT_NOBITS, "symbol string table has no bytes")
        strings = data[strings_section["offset"]:strings_section["offset"] + strings_section["size"]]
        entries = []
        for index in range(section["size"] // SYMBOL.size):
            name_offset, info, _, section_index, value, size = SYMBOL.unpack_from(
                data, section["offset"] + index * SYMBOL.size
            )
            entries.append({
                "index": index,
                "name": read_c_string(strings, name_offset, "symbol") if name_offset else "",
                "binding": info >> 4,
                "type": info & 0x0F,
                "section_index": section_index,
                "value": value,
                "size": size,
            })
        symbol_tables[section["index"]] = entries
    require(symbol_tables, "ELF has no symbol table")
    return sections, symbol_tables


def locate_symbol(data, spec):
    sections, symbol_tables = parse_elf(data)
    matches = []
    for table_index, entries in symbol_tables.items():
        for entry in entries:
            if entry["name"] == spec["symbol"]:
                matches.append((table_index, entry))
    require(len(matches) == 1, f"expected one {spec['symbol']} symbol, found {len(matches)}")
    table_index, symbol = matches[0]
    require(symbol["binding"] == STB_GLOBAL and symbol["type"] == STT_FUNC, "unexpected target symbol type")
    require(symbol["section_index"] == spec["section_index"], "unexpected target symbol section index")
    require(symbol["value"] == spec["value"] and symbol["size"] == spec["symbol_size"], "unexpected target symbol range")
    section = sections[symbol["section_index"]]
    require(section["name"] == spec["section"], "unexpected target symbol section")
    file_offset = section["offset"] + symbol["value"]
    require(file_offset == spec["file_offset"], "unexpected target file offset")
    require(file_offset + len(spec["preimage"]) <= len(data), "target bytes are out of bounds")
    return sections, symbol_tables, table_index, symbol, file_offset


def validate_relocations(data, sections, symbol_tables, symbol_table_index, symbol, spec):
    required_relocation = spec["required_relocation"]
    found_required = required_relocation is None
    for section in sections:
        if section["kind"] != SHT_RELA or section["info"] != symbol["section_index"]:
            continue
        require(section["link"] == symbol_table_index, "target relocation uses an unexpected symbol table")
        require(section["entry_size"] == RELA.size, "unexpected relocation entry size")
        symbols = symbol_tables[symbol_table_index]
        for index in range(section["size"] // RELA.size):
            offset, info, _ = RELA.unpack_from(data, section["offset"] + index * RELA.size)
            if symbol["value"] <= offset < symbol["value"] + len(spec["preimage"]):
                raise ValidationError("target instruction range contains a relocation")
            symbol_index = info >> 32
            require(symbol_index < len(symbols), "relocation references an invalid symbol")
            if required_relocation and symbol["value"] <= offset < symbol["value"] + symbol["size"]:
                found_required = found_required or symbols[symbol_index]["name"] == required_relocation
    require(found_required, f"target function does not reference {required_relocation}")


def write_atomic(path, data, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    require(path.parent.is_dir() and not path.parent.is_symlink(), f"invalid output directory: {path.parent}")
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def patch_module(source_dir, output_dir, name, spec):
    source = source_dir / name
    data = read_regular(source)
    require(len(data) == spec["size"], f"unexpected size for {name}")
    require(digest(data) == spec["source_sha256"], f"unexpected SHA-256 for {name}")
    sections, symbol_tables, table_index, symbol, offset = locate_symbol(data, spec)
    validate_relocations(data, sections, symbol_tables, table_index, symbol, spec)
    require(data[offset:offset + len(spec["preimage"])] == spec["preimage"], f"unexpected instruction preimage for {name}")

    patched = bytearray(data)
    patched[offset:offset + len(spec["replacement"])] = spec["replacement"]
    require(patched[offset:offset + len(spec["replacement"])] == spec["replacement"], f"failed to patch {name}")
    require(patched[:offset] == data[:offset] and patched[offset + len(spec["replacement"]):] == data[offset + len(spec["replacement"]):], f"patch escaped its target range for {name}")
    changed = sum(before != after for before, after in zip(data, patched))
    require(changed == spec["changed_bytes"], f"unexpected byte delta for {name}: {changed}")
    require(digest(patched) == spec["output_sha256"], f"unexpected patched SHA-256 for {name}")
    write_atomic(output_dir / name, patched, 0o644)


def copy_stock_module(source_dir, output_dir, name, expected_digest, expected_size):
    data = read_regular(source_dir / name)
    require(len(data) == expected_size, f"unexpected size for {name}")
    require(digest(data) == expected_digest, f"unexpected SHA-256 for {name}")
    write_atomic(output_dir / name, data, 0o644)


def build_modules_dep(source_dir, output_dir):
    data = read_regular(source_dir / "modules.dep")
    require(digest(data) == PLATFORM_DEP_SHA256, "unexpected SHA-256 for platform modules.dep")
    text = data.decode("ascii")
    require(text.endswith("\n") and "\r" not in text, "invalid platform modules.dep text")
    lines = text.splitlines()
    for dependency in REQUIRED_PLATFORM_DEPENDENCIES:
        require(dependency in lines, f"missing platform dependency: {dependency}")
    for name in ("scp.ko", "goodix_core_dali.ko") + tuple(COPY_SPECS):
        require(not any(line.startswith(f"/lib/modules/{name}:") or line.startswith(f"{name}:") for line in lines), f"platform modules.dep unexpectedly contains {name}")
    merged = text + "\n".join(RECOVERY_DEPENDENCIES) + "\n"
    require("/vendor_dlkm/" not in merged, "merged modules.dep must not reference vendor_dlkm")
    for dependency in RECOVERY_DEPENDENCIES:
        require(merged.count(dependency) == 1, f"unexpected duplicate dependency: {dependency}")
    merged_data = merged.encode("ascii")
    write_atomic(output_dir / "modules.dep", merged_data, 0o644)
    return merged_data


def validate_published(output_dir, expected_modules_dep):
    for name, spec in MODULE_SPECS.items():
        output = read_regular(output_dir / name)
        require(digest(output) == spec["output_sha256"], f"published hash mismatch for {name}")
    for name, (expected_digest, _) in COPY_SPECS.items():
        output = read_regular(output_dir / name)
        require(digest(output) == expected_digest, f"published hash mismatch for {name}")
    modules_dep = read_regular(output_dir / "modules.dep")
    require(modules_dep == expected_modules_dep, "published modules.dep does not match the validated merge")


def publish_staged(staging_dir, output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    require(output_dir.is_dir() and not output_dir.is_symlink(), f"invalid output directory: {output_dir}")
    backup_dir = Path(tempfile.mkdtemp(prefix=".dali-ap-touch-backup.", dir=output_dir.parent))
    published = []
    backed_up = []
    try:
        for name in PUBLISHED_FILES:
            target = output_dir / name
            if target.exists() or target.is_symlink():
                os.replace(target, backup_dir / name)
                backed_up.append(name)
            os.replace(staging_dir / name, target)
            published.append(name)
    except BaseException:
        for name in published:
            target = output_dir / name
            if target.exists() or target.is_symlink():
                target.unlink()
        for name in backed_up:
            os.replace(backup_dir / name, output_dir / name)
        raise
    finally:
        shutil.rmtree(backup_dir, ignore_errors=True)


def main():
    if len(sys.argv) != 3:
        raise ValidationError("usage: patch-ap-touch-modules.py INPUT_DIRECTORY OUTPUT_DIRECTORY")
    source_argument = Path(sys.argv[1])
    output_argument = Path(sys.argv[2])
    require(not source_argument.is_symlink(), f"input directory must not be a symlink: {source_argument}")
    require(not output_argument.is_symlink(), f"output directory must not be a symlink: {output_argument}")
    source_dir = source_argument.resolve(strict=True)
    output_dir = output_argument.resolve(strict=False)
    require(source_dir.is_dir() and not source_dir.is_symlink(), f"invalid input directory: {source_dir}")
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    require(output_dir.parent.is_dir() and not output_dir.parent.is_symlink(), f"invalid output parent: {output_dir.parent}")
    staging_dir = Path(tempfile.mkdtemp(prefix=".dali-ap-touch-stage.", dir=output_dir.parent))
    try:
        for name, spec in MODULE_SPECS.items():
            patch_module(source_dir, staging_dir, name, spec)
        for name, (expected_digest, expected_size) in COPY_SPECS.items():
            copy_stock_module(source_dir, staging_dir, name, expected_digest, expected_size)
        expected_modules_dep = build_modules_dep(source_dir, staging_dir)
        validate_published(staging_dir, expected_modules_dep)
        publish_staged(staging_dir, output_dir)
        validate_published(output_dir, expected_modules_dep)
    finally:
        shutil.rmtree(staging_dir, ignore_errors=True)
    for name, spec in MODULE_SPECS.items():
        print(f"{name}: {spec['output_sha256']}")
    print(f"xiaomi_touch_dali.ko: {XIAOMI_TOUCH_SHA256}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, UnicodeError, ValidationError) as error:
        print(f"dali AP touch module generator: {error}", file=sys.stderr)
        raise SystemExit(2)
