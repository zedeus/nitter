import router_utils, timeline

proc createJsonApiRouter*(cfg: Config) =
    router jsonapi:
        get "/hello":
            cond cfg.enableJsonApi
            let headers = ["Content-Type": "application/json; charset=utf-8"]
            resp Http200, headers, """{"message": "Hello, world"}"""