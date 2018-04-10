#!ruby -w

# Simple tool to benchmark CPUMiner (KlauS fork).
# Version 0.1.  This version is for windows only.

# Due to changes in the KlauS fork of ccminer, this script currently requires you to manually read
#   the hashrate reports and determine the average hashrate.

# These algorithms are not benchmarked:
#     deep: incorrect results
#     whirl: CUDA errors
#     whirlpoolx: soft-crashes NVIDIA drivers

# These algorithms require a longer time to test (25 seconds works):
#     "jackpot", "neoscrypt", "nist5", "s3"

require 'timeout'

# Time to run for
timeLimit = 15

# Algorithms to benchmark
algos = ["bitcoin", "blake", "blakecoin", "c11", "dmd-gr", "fresh", "fugue256", "groestl", "keccak", "luffa", "lyra2v2", "myr-gr", "penta", "quark", "qubit", "sia", "skein", "x11", "x13", "x14", "x15", "x17", "vanilla"]

algos.each{ |algo|
	puts "Benchmarking #{algo}"

    io = IO.popen("ccminer.exe -q --no-color --benchmark -a #{algo} 2>&1")
	
	# timeout thread (this fork does not have time limit option)
	timeout = Thread.new {
		begin
			# sleep for 15 seconds (some algorithms require ~10 seconds to get going)
			Timeout.timeout(timeLimit) {
			
				Process.wait(io.pid)
				# If we get here then process is already stopped
			}
		rescue Timeout::Error
			# Timeout expired, kill process
			system("taskkill /T /f /pid #{io.pid}")
		end
	}
	
	# read output
    out = io.readlines
	
	# Wait for timeout to finish
	timeout.join()
	
	# Print hashrate
	puts out
}

