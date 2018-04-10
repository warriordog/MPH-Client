#!ruby -w

# Simple tool to benchmark CPUMiner.
# Version 0.1.  This version is cross-platform.

# These algorithms are not benchmarked:
#   bmw: cuda errors
#   heavy: gets stuck
#   wildkeccak: Needs a scratchpad
#   mojollnir: gets stuck

# Time to run for
timeLimit = 10

# Algorithms to benchmark
algos = ["bastion", "bitcore", "blake", "blake2s", "blakecoin", "c11", "cryptolight", "cryptonight", "decred", "deep", "equihash", "dmd-gr", "fresh", "fugue256", "groestl", "hmq1725", "jackpot", "keccak", "keccakc", "lbry", "luffa", "lyra2", "lyra2v2", "lyra2z", "myr-gr", "neoscrypt", "nist5", "penta", "phi", "polytimos", "quark", "qubit", "sha256d", "sha256t", "sia", "sib", "scrypt", "scrypt-jane", "skein", "skein2", "skunk", "s3", "timetravel", "tribus", "vanilla", "veltor", "whirlcoin", "whirlpool", "x11evo", "x11", "x13", "x14", "x15", "x17", "zr5"]

# Pick correct executable name
if (Gem.win_platform?)
	executable = "ccminer.exe"
else
	executable = "./ccminer"
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
