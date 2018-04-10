#!ruby -w

# Simple tool to benchmark CPUMiner-Optimized.
# Version 0.1.  This version is cross-platform.

# These algorithms are not benchmarked:
#   bastion: gets stuck and doesn't finish benchmark
#   bmw: algo errors
#   heavy: algo errors
#   lyra2z330: gets stuck
#   shavite3: algo errors
#   x16r: gets stuck)

# Time to run for
timeLimit = 10

# Algorithms to benchmark
algos = ["allium", "anime", "argon2", "axiom", "blake", "blakecoin", "blake2s", "c11", "cryptolight", "cryptonight", "decred", "deep", "dmd-gr", "drop", "groestl", "keccak", "keccakc", "lbry", "luffa", "lyra2h", "lyra2re", "lyra2rev2", "lyra2z", "m7m", "myr-gr", "neoscrypt", "nist5", "pentablake", "phi1612", "pluck",  "polytimos", "quark", "qubit", "scrypt", "sha256d", "sha256t", "skein", "skein2", "skunk", "timetravel", "timetravel10", "tribus", "vanilla", "veltor", "whirlpool", "whirlpoolx", "x11", "x11evo", "x11gost", "x12", "x13", "x13sm3", "x14", "x15", "x17", "xevan", "yescrypt", "zr5"]

# Pick correct executable name
if (Gem.win_platform?)
	executable = "cpuminer.exe"
else
	executable = "./cpuminer"
end

# Do the benchmark
algos.each{ |algo|
	# Run the miner
	io = IO.popen("#{executable} -q --time-limit=#{timeLimit} --benchmark -a #{algo} 2>&1")
	
	# Read output into array
    out = io.readlines
	
	# Last output value is hashrate in H/s
    puts "#{algo}: #{out[-1]}"
}
