import random, strformat, strutils, sequtils

randomize()

const rvs = [
  "11.0", "40.0", "42.0", "43.0", "47.0", "50.0", "52.0", "53.0", "54.0",
  "61.0", "66.0", "67.0", "69.0", "70.0"
]

proc rv(): string =
  if rand(10) < 1: ""
  else: "; rv:" & sample(rvs)

# OS

const enc = ["; U", "; N", "; I", ""]

proc linux(): string =
  const
    window = ["X11", "Wayland", "Unknown"]
    arch = ["i686", "x86_64", "arm"]
    distro = ["", "; Ubuntu/14.10", "; Ubuntu/16.10", "; Ubuntu/19.10",
              "; Ubuntu", "; Fedora"]
  sample(window) & sample(enc) & "; Linux " & sample(arch) & sample(distro)

proc windows(): string =
  const
    nt = ["5.1", "5.2", "6.0", "6.1", "6.2", "6.3", "6.4", "9.0", "10.0"]
    arch = ["; WOW64", "; Win64; x64", "; ARM", ""]
    trident = ["", "; Trident/5.0", "; Trident/6.0", "; Trident/7.0"]
  "Windows " & sample(nt) & sample(enc) & sample(arch) & sample(trident)

let macs = toSeq(6..15).mapIt($it) & @["14_4", "10_1", "9_3"]

proc mac(): string =
  "Macintosh; Intel Mac OS X 10_" & sample(macs) & sample(enc)

# Browser

proc presto(): string =
  const p = ["2.12.388", "2.12.407", "22.9.168", "2.9.201", "2.8.131", "2.7.62",
             "2.6.30", "2.5.24"]
  const v = ["10.0", "11.0", "11.1", "11.5", "11.6", "12.00", "12.14", "12.16"]
  &"Presto/{sample(p)} Version/{sample(v)}"

# Samples

proc product(): string =
  const opera = ["Opera/9.80", "Opera/12.0"]
  if rand(20) < 1: "Mozilla/5.0"
  else: sample(opera)

proc os(): string =
  let r = rand(10)
  let os =
    if r < 6: windows()
    elif r < 9: linux()
    else: mac()
  &"({os}{rv()})"

proc browser(prod: string): string =
  if "Opera" in prod: presto()
  else: "like Gecko"

# Agent

proc getAgent*(): string =
  let prod = product()
  &"{prod} {os()} {browser(prod)}"
