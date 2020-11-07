--define:ssl
--define:useStdLib

# workaround httpbeast file upload bug
--assertions:off

# disable annoying warnings
warning("GcUnsafe2", off)
warning("ObservableStores", off)
