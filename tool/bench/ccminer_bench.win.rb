#!ruby -w

# Simple tool to benchmark CPUMiner.  This version is for Windows only.

# These algorithms are not benchmarked:
#   c11/flax: can't figure out actual algo name
#   bmw: CUDA errors
#   wildkeccak: Needs a scratchpad
algos = ["bastion", "bitcore", "blake", "blake2s", "blakecoin", "cryptolight", "cryptonight", "decred", "deep", "equihash", "dmd-gr", "fresh", "fugue256", "groestl", "heavy", "hmq1725", "jackpot", "keccak", "keccakc", "lbry", "luffa", "lyra2", "lyra2v2", "lyra2z", "mjollnir", "myr-gr", "neoscrypt", "nist5", "penta", "phi", "polytimos", "quark", "qubit", "sha256d", "sha256t", "sia", "sib", "scrypt", "scrypt-jane", "skein", "skein2", "skunk", "s3", "timetravel", "tribus", "vanilla", "veltor", "whirlcoin", "whirlpool", "x11evo", "x11", "x13", "x14", "x15", "x17", "zr5"]

algos.each{ |algo|
    io = IO.popen("ccminer-x64.exe -q --time-limit=8 --benchmark -a #{algo} 2>&1")
    out = io.readlines
	#puts out
    puts "#{algo}: #{out[-1]}"
}

