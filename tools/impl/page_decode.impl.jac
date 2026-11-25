impl declared_codec(raw: bytes) -> str | None {
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")) {
        return "utf-16";
    }
    found: any = META_CHARSET.search(raw[:PRESCAN_BYTES]);
    return LABEL_TO_CODEC.get(found.group(1).decode("ascii").lower()) if found else None;
}

impl decode_page(raw: bytes) -> str {
    try {
        return raw.decode("utf-8");
    } except UnicodeDecodeError {
        return raw.decode(declared_codec(raw) or "utf-8", errors="replace");
    }
}
