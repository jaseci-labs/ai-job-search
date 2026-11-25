impl declared_codec(raw: builtins.bytes) -> any {
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")) {
        return "utf-16";
    }
    `match: any = META_CHARSET.search(raw[:PRESCAN_BYTES]);
    if `match is None {
        return None;
    }
    return LABEL_TO_CODEC.get(`match.group(1).decode("ascii").lower());
}

impl decode_page(raw: builtins.bytes) -> builtins.str {
    try {
        return raw.decode("utf-8");
    } except UnicodeDecodeError {}
    return raw.decode(declared_codec(raw) or "utf-8", errors="replace");
}
