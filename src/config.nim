import parsecfg except Config
import types, strutils

proc get*[T](config: parseCfg.Config; s, v: string; default: T): T =
  let val = config.getSectionValue(s, v)
  if val.len == 0: return default

  when T is int: parseInt(val)
  elif T is bool: parseBool(val)
  elif T is string: val

proc getConfig*(path: string): (Config, parseCfg.Config) =
  var cfg = loadConfig(path)

  let conf = Config(
    address: cfg.get("Server", "address", "0.0.0.0"),
    port: cfg.get("Server", "port", 8080),
    useHttps: cfg.get("Server", "https", true),
    title: cfg.get("Server", "title", "Nitter"),
    hostname: cfg.get("Server", "hostname", "nitter.net"),
    staticDir: cfg.get("Server", "staticDir", "./public"),

    hmacKey: cfg.get("Config", "hmacKey", "secretkey"),
    base64Media: cfg.get("Config", "base64Media", false),
    minTokens: cfg.get("Config", "tokenCount", 10),

    listCacheTime: cfg.get("Cache", "listMinutes", 120),
    rssCacheTime: cfg.get("Cache", "rssMinutes", 10),

    redisHost: cfg.get("Cache", "redisHost", "localhost"),
    redisPort: cfg.get("Cache", "redisPort", 6379),
    redisConns: cfg.get("Cache", "redisConnections", 20),
    redisMaxConns: cfg.get("Cache", "redisMaxConnections", 30)
  )

  return (conf, cfg)
