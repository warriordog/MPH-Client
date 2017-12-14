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
require_relative 'coins'
require_relative 'miners'

module MPHClient
    # Global logger (default creation is temporary until config is loaded)
    @@rootLog = Log.createLogger('?', false, true)

    def self.runMainLoop(workers)
        running = true

        # setup coin change timer
        timerThread = Thread.new {
            logger = Log.createLogger("SwitchTimer")
            
            logger.debug("Coin switch thread started - will update all miners every #{Config.settings[:switch_interval]} seconds.")
            while (running)
                # download stats
                stats = MPH.getMiningAndProfitsStatistics()
                
                # check stats
                if (stats != nil)
                    # switch (or not)
                    workers.each {|w| w.switchAlgo(stats)}
                else
                    logger.error("Unable to get stats, stopping miners.")
                    workers.each {|w| w.stopMining()}
                end
                
                # Only change every n seconds
                sleep(Config.settings[:switch_interval])
            end
        }
        
        # add new stuff here
        
        # Wait for all threads to end
        timerThread.join()
    end
    
    def self.start()
        # Print version
        @@rootLog.info("MPH-Client v0.0.0 (development)")

        # Load config
        if (ARGV.length > 0)
            configFile = ARGV[0]
            if (File.file?(configFile))
                Config.loadConfig(configFile)
                if (Config.cfg != nil)            
                    # Set up logging
                    Log.defaultLogToFile = Config.settings[:log_to_file]
                    Log.defaultMinLevel = Logger::Severity.const_get(Config.settings[:log_level])
                    
                    # Create "real" root logger
                    @@rootLog = Log.createLogger("root")
                
                    # Load coins and algorithms
                    Coins.loadAlgorithms()
                
                    # Load miners
                    Miners.loadMiners()
                
                    # Load workers
                    workers = Wkr.loadWorkers()
                    
                    # Start mining
                    @@rootLog.info("Starting mine cycle.")
                    runMainLoop(workers)
                else
                    @@rootLog.fatal("Failed to load config file.  Please check for errors!")
                end
            else
                @@rootLog.fatal("Config file '#{configFile}' does not exist.")
            end
        else
            @@rootLog.info("Usage: ruby main.rb <config_json>")
        end
    end
    
    def self.rootLog()
        return @@rootLog
    end
end

#
# Main entry point
#

MPHClient.start()

