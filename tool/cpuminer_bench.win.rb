#!ruby -w

# Simple tool to benchmark CPUMiner.  For Windows only.

# These algorithms are not benchmarked:
#   c11/flax: can't figure out actual algo name
#   fresh: bugged (smashes its own stack)
algos = ["axiom", "bitcore", "blake", "blakecoin", "blake2s", "bmw", "cryptolight", "cryptonight", "decred", "dmd-gr", "drop", "groestl", "heavy", "jha", "keccak", "luffa", "lyra2re", "lyra2rev2", "myr-gr", "neoscrypt", "nist5", "pluck", "pentablake", "quark", "qubit", "scrypt", "shavite3", "sha256d", "sia", "sib", "skein", "skein2", "s3", "timetravel", "vanilla", "x11evo", "x11", "x13", "x14", "x15", "x17", "xevan", "yescrypt", "zr5"]

algos.each{ |algo|
    io = IO.popen("cpuminer.exe -q --time-limit=8 --benchmark -a #{algo} 2>&1")
    out = io.readlines
    puts "#{algo}: #{out[-1]}"
}

