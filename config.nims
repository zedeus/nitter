--define:ssl
--define:useStdLib
--threads:off

# workaround httpbeast file upload bug
--assertions:off

# disable annoying warnings
warning("GcUnsafe2", off)
warning("HoleEnumConv", off)
hint("XDeclaredButNotUsed", off)
hint("XCannotRaiseY", off)
hint("User", off)
# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
