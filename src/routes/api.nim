import router_utils, timeline

proc createApiRouter*(cfg: Config) =
    router api:
        get "/hello":
            cond cfg.enableApi
            let headers = ["Content-Type": "application/json; charset=utf-8"]
            resp Http200, headers, """{"message": "Hello, world"}"""