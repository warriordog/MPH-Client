#!ruby -w

# Simple tool to benchmark CPUMiner.
# Version 0.1.  This version is cross-platform.

# These algorithms are not benchmarked:
#   heavy: gets stuck and doesn't finish benchmark
#   fresh: bugged (smashes its own stack)

# Time to run for
timeLimit = 10

# Algorithms to benchmark
algos = ["axiom", "blake", "blakecoin", "blake2s", "bmw", "c11", "cryptolight", "cryptonight", "decred", "dmd-gr", "drop", "groestl", "keccak", "luffa", "lyra2re", "lyra2rev2", "myr-gr", "neoscrypt", "nist5", "pluck", "pentablake", "quark", "qubit", "scrypt", "shavite3", "sha256d", "sia", "sib", "skein", "skein2", "s3", "timetravel", "vanilla", "x11evo", "x11", "x13", "x14", "x15", "x17", "xevan", "yescrypt", "zr5"]

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
