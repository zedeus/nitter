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
