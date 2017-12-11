#!ruby

#-----------------------------
# MPH-Client main source file
#-----------------------------

# Include required libraries
require 'json'
require 'net/http'

# Include other project files
require_relative 'config'
require_relative 'worker'
require_relative 'mph'

def runMainLoop(settings, workers)
    running = true

    # setup coin change timer
    timerThread = Thread.new {
        puts "Coin switch thread started - will update all miners every #{settings['switch_interval']} seconds."
        while running
            # download stats
            stats = mph_getMiningAndProfitsStatistics()
            
            # check stats
            if (stats != nil)
                # switch (or not)
                workers.each {|w| w.switchAlgo(settings, stats)}
            else
                puts "Unable to get stats, stopping miners."
                workers.each {|w| w.stopMining()}
            end
            
            # Only change every n seconds
            sleep(settings['switch_interval'])
        end
    }
    
    # add new stuff here
    
    # Wait for all threads to end
    timerThread.join()
end

#
# Main entry point
#

# Load config
if (ARGV.length > 0)
    configFile = ARGV[0]
    if (File.file?(configFile))
        config = loadConfig(configFile)
        if (config != nil)
            # Read settings
            settings = config['settings']
        
            # Load workers
            workers = loadWorkers(config['workers'])
            
            # Start mining
            runMainLoop(settings, workers)
        else
            puts "Error: failed to load config file.  Please check for errors!"
        end
    else
        puts "Error: config file '#{configFile}' does not exist."
    end
else
    puts "Usage: ruby main.rb <config_json>"
end
