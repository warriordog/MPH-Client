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
require_relative 'log'

def runMainLoop(settings, workers)
    running = true

    # setup coin change timer
    timerThread = Thread.new {
        logger = Log.createLogger("switch_timer", true, true)
        
        logger.debug("Coin switch thread started - will update all miners every #{settings['switch_interval']} seconds.")
        while running
            # download stats
            stats = mph_getMiningAndProfitsStatistics()
            
            # check stats
            if (stats != nil)
                # switch (or not)
                workers.each {|w| w.switchAlgo(settings, stats)}
            else
                logger.error("Unable to get stats, stopping miners.")
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

# Print version
Log::Global.info("MPH-Client v0.0.0 (development)")

# Load config
if (ARGV.length > 0)
    configFile = ARGV[0]
    if (File.file?(configFile))
        config = loadConfig(configFile)
        if (config != nil)
            # Read settings
            settings = config['settings']
            
            # Set up logging
            Log::Global.progname = "root"
            if (settings['log_to_file'] == true)
                Log.changeLogMode(Log::Global, true, true)
            end
            logLevel = Logger::Severity.const_get(settings['log_level'])
            if (logLevel != nil)
                Log::Global.level = logLevel
            end
        
            # Load workers
            workers = loadWorkers(config['workers'])
            
            # Start mining
            runMainLoop(settings, workers)
        else
            Log::Global.info("Error: failed to load config file.  Please check for errors!")
        end
    else
        Log::Global.fatal("Error: config file '#{configFile}' does not exist.")
    end
else
    Log::Global.info("Usage: ruby main.rb <config_json>")
end
