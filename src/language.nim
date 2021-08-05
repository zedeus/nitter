import json, types, config, tables
from os import getEnv

let configPath = getEnv("NITTER_CONF_FILE", "nitter.conf")
let (cfg, fullCfg) = getConfig(configPath)

var jsonData =  parseJson(readFile("src/lang/" & cfg.language & ".json"))

var lang* = initTable[string, string]()

for i in jsonData.keys:
    lang[i] = jsonData[i].getStr
