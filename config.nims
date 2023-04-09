--define:ssl
--define:useStdLib
--threads:off

# workaround httpbeast file upload bug
--assertions:off

# disable annoying warnings
warning("GcUnsafe2", off)
hint("XDeclaredButNotUsed", off)
hint("XCannotRaiseY", off)
hint("User", off)

const
  nimVersion = (major: NimMajor, minor: NimMinor, patch: NimPatch)

when nimVersion >= (1, 6, 0):
  warning("HoleEnumConv", off)
