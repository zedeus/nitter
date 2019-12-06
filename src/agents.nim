import random, strformat, strutils

randomize()

const blacklist = [
  "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/38.0",
  "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/40.1",
  "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/43.0",
  "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/50.0",
  "Mozilla/5.0 (X11; Linux x86_64) like Gecko",
]

const rvs = [
  "11.0", "40.0", "42.0", "43.0", "47.0", "50.0", "52.0", "53.0", "54.0",
  "61.0", "66.0", "67.0"
]

proc rv(): string =
  if rand(5) < 3: ""
  else: "; rv:" & sample(rvs)

# OS

proc linux(): string =
  const
    os = ["Linux", "CrOS"]
    arch = [" i686", " x86_64"]
    distro = ["", "; Ubuntu/14.10", "; Ubuntu/16.10", "; Ubuntu/19.10", "; Ubuntu"]
  "X11; " & sample(os) & sample(arch) & sample(distro)

proc windows(): string =
  const
    nt = ["5.1", "5.2", "6.0", "6.1", "6.2", "6.3", "6.4", "9.0", "10.0"]
    arch = ["; WOW64", "; Win64; x64", "; ARM", ""]
    trident = ["", "; Trident/5.0", "; Trident/6.0", "; Trident/7.0"]
  "Windows " & sample(nt) & sample(arch) & sample(trident)

proc mac(): string =
  const v = ["Intel Mac OS X 10_12", "Intel Mac OS X 10_11", "Intel Mac OS X 10_10_1",
              "Intel Mac OS X 10_9_3"]
  "Macintosh; " & sample(v)

# Browser

const safariV = [
  "536.25", "536.26", "536.26.17", "536.28.10", "536.29.13", "536.30.1",
  "537.32", "537.36", "537.43.58", "537.73.11", "537.85.17", "537.71",
  "537.73.11", "537.75.14", "537.76.4", "537.77.4", "537.78.2",
  "537.85.17", "538.35.8", "600.6.3", "600.7.12", "601.1.56", "601.2.7",
  "601.3.9", "601.4.4", "601.5.17", "601.6.17", "601.7.1", "601.7.8",
  "602.1.50", "602.2.14", "602.3.12", "602.4.8", "603.1.30", "603.2.4",
  "603.3.8", "604.1.28"
]

proc appleWebKit(): string =
  "AppleWebKit/" & sample(safariV) & " (KHTML, like Gecko) "

proc safari(): string =
  const edge = ["", "", " Edge/16.16299"]
  " Safari/" & sample(safariV) & sample(edge)

proc chrome(): string =
  const v = [
    "41.0.2224.3", "41.0.2225.0", "41.0.2226.0", "41.0.2227.0", "41.0.2227.1",
    "41.0.2228.0", "49.0.2623.112", "57.0.2987.133", "58.0.3029.110",
    "59.0.3071.115", "61.0.3163.100", "63.0.3239.132", "63.0.3239.84",
    "64.0.3282.186", "65.0.3325.181", "67.0.3396.99", "68.0.3440.106",
    "69.0.3497.100", "70.0.3538.102", "70.0.3538.110", "70.0.3538.77",
    "72.0.3626.121", "74.0.3729.131"]
  "Chrome/" & sample(v)

proc firefox(): string =
  const v = [
    "38.0", "40.1", "43.0", "50.0", "52.0", "53.0", "60.0", "60.0.2", "60.0.1",
    "61.0", "61.0.1", "66.0", "67.0"]
  "Gecko/20100101 Firefox/" & sample(v)

proc presto(): string =
  const p = ["2.12.388", "2.12.407", "22.9.168"]
  const v = ["12.00", "12.14", "12.16"]
  &"Presto/{sample(p)} Version/{sample(v)}"

proc opr(): string =
  const v = [
    "43.0.2442.991", "36.0.2130.32", "56.0.3051.52", "47.0.2631.39",
    "42.0.2393.94", "49.0.2711.0", "34.0.2036.25", "52.0.2871.99",
    "33.0.1990.115", "53.0.2907.99"
  ]
  " OPR/" & sample(v)

proc others(): string =
  const v = ["Version/7.0.3 Safari/7046A194A", "like Gecko"]
  sample(v)

# Samples

proc product(): string =
  const opera = ["Opera/9.80", "Opera/12.0"]
  if rand(10) < 8: "Mozilla/5.0"
  else: sample(opera)

proc os(): string =
  let os =
    case rand(0)
    of 0: linux()
    of 1: windows()
    else: mac()
  &"({os}{rv()})"

proc browser(os: string; prod: string): string =
  if "Opera" in os:
    if rand(1) == 0: return presto()
    else: return appleWebKit() & chrome() & safari() & opr()

  let r = rand(100)
  if r < 20: "like Gecko"
  elif r < 60 and "CrOS" notin os: appleWebKit() & chrome() & safari()
  else: firefox()

# Agent

proc getAgent*(): string =
  let prod = product()
  let os = os()
  result = &"{prod} {os} {browser(os, prod)}"
  if result in blacklist:
    result = getAgent()
