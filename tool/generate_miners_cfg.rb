require 'json'

# Generates the "miners" config section from the output of a benchmarking tool.
#  Expects lines with the algo name followed by non-alphanumeric divider (with at least one whitespace) and then the hashrate in H/s

if (ARGV.length == 2)
    miner = ARGV[0]

    if (File.exists? (ARGV[1]))
        algos = []
    
        File.readlines(ARGV[1]).each {|line| 
            parts = line.split(/[^\w\d]*\s+[^\w\d]*/)
            if (parts.length == 2)
                algo = {}
                algo["id"] = parts[0]
                algo["miners"] = []
                algMiner = {}
                algMiner["id"] = miner
                algMiner["rate"] = parts[1].to_i
                algo["miners"] << algMiner
                algos << algo
            else
                puts "Malformed line: #{line}"
            end
        }
        
        puts algos.to_json()
    else
        puts "Input file does not exist."
    end
else
    puts "Usage: ruby generate_miners.rb <miner_name> <rate_file>"
end
