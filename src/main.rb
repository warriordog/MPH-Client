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

module MPHClient
    # Global logger
    RootLog = Log.createLogger('?', false, true)

    def self.runMainLoop(workers)
        running = true

        # setup coin change timer
        timerThread = Thread.new {
            logger = Log.createLogger("switch_timer", true, true)
            
            logger.debug("Coin switch thread started - will update all miners every #{Config.settings[:switch_interval]} seconds.")
            while running
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
        RootLog.info("MPH-Client v0.0.0 (development)")

        # Load config
        if (ARGV.length > 0)
            configFile = ARGV[0]
            if (File.file?(configFile))
                Config.loadConfig(configFile)
                if (Config.cfg != nil)            
                    # Set up logging
                    RootLog.progname = "root"
                    if (Config.settings[:log_to_file] == true)
                        Log.changeLogMode(RootLog, true, true)
                    end
                    logLevel = Logger::Severity.const_get(Config.settings[:log_level])
                    if (logLevel != nil)
                        RootLog.level = logLevel
                    end
                
                    # Load workers
                    workers = Wkr.loadWorkers(Config.workers)
                    
                    # Start mining
                    runMainLoop(workers)
                else
                    RootLog.info("Error: failed to load config file.  Please check for errors!")
                end
            else
                RootLog.fatal("Error: config file '#{configFile}' does not exist.")
            end
        else
            RootLog.info("Usage: ruby main.rb <config_json>")
        end
    end
end

#
# Main entry point
#

MPHClient.start()

