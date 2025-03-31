import router_utils, timeline

proc createJsonRouter*(cfg: Config) =
    router api:
        get "/hello":
            cond cfg.enableJson
            let headers = ["Content-Type": "application/json; charset=utf-8"]
            resp Http200, headers, """{"message": "Hello, world"}"""