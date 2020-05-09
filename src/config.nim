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
    staticDir: cfg.get("Server", "staticDir", "./public"),
    title: cfg.get("Server", "title", "Nitter"),
    hostname: cfg.get("Server", "hostname", "nitter.net"),

    cacheDir: cfg.get("Cache", "directory", "/tmp/nitter"),
    profileCacheTime: cfg.get("Cache", "profileMinutes", 10),

    hmacKey: cfg.get("Config", "hmacKey", "secretkey")
  )

  return (conf, cfg)
