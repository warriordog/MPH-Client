#!ruby

#-----------------------------
# MPH-Client main source file
#-----------------------------

require 'config'
require 'util/watchdog'
require 'util/log'
require 'miner/worker'
require 'miner/coins'
require 'miner/miners'
require 'api/mph'
require 'miner/event/triggers'
require 'miner/event/actions'
require 'util/application'

module MPHClient
    # Global logger (default creation is temporary until config is loaded)
    @@rootLog = Log.createLogger('?', toFile: false, toConsole: true)

    def self.runMainLoop(workers)
        running = true
        
        # Startup workers
        workers.each {|worker| worker.startup()}
        
        # setup coin change timer
        timerThread = Thread.new {
            logger = Log.createLogger("SwitchTimer")
            
            logger.debug("Coin switch thread started - will update all miners every #{Config.settings[:switch_interval]} seconds.")
            while (running)
                begin
                    # download stats
                    stats = MPH.getMiningAndProfitsStatistics()
                    
                    # check stats
                    if (stats != nil)
                        # switch (or not)
                        workers.each {|w| w.switchAlgo(stats)}
                    
                        # Sleep until next switch interval
                        sleep Config.settings[:switch_interval]
                    else
                        # Time until attempt to reconnect
                        delay = Config.settings[:reconnect_interval]
                        
                        logger.error("Unable to get stats, stopping miners.  Trying again in #{delay} seconds.")
                        workers.each {|w| w.stopMining()}
                        
                        sleep delay
                    end
                rescue Interrupt => i
                    # Interrupt just breaks us out of timer loop
                rescue Exception => e
                    @@rootLog.error "Exception in main loop"
                    @@rootLog.error e.message
                    @@rootLog.error e.backtrace.join("\n\t")
                end
            end
        }
        timerThread.name = "timer"
        timerThread.daemon = false
        
        # Make sure we can stop
        Signal.trap("INT") {
            #@@rootLog.info "Interrupt recieved, shutting down."
            
            running = false
            
            # Stop timer
            timerThread.raise Interrupt.new
        }
        
        # Wait for timer to exit (which means we are shutting down)
        timerThread.join()
        
        # Shut down
        @@rootLog.info "Shutting down."
        workers.each {|worker| worker.shutdown()}
    end
    
    def self.start()
        # Print version
        @@rootLog.info("MPH-Client v0.2.0 (development)")

        # Load config
        if (ARGV.length > 0)
            configFile = ARGV[0]
            if (File.file?(configFile))
                if (Config.loadConfig(configFile)) 
                    if (!Config.workers.empty?)
                        # Set up logging
                        Log.defaultLogToFile = Config.settings[:log_to_file]
                        Log.defaultMinLevel = Logger::Severity.const_get(Config.settings[:log_level])
                        
                        # Create "real" root logger
                        @@rootLog = Log.createLogger("root")
                        @@rootLog.info "Starting up."
                    
                        # Load applications
                        Application.loadApps()
                    
                        # Load coins and algorithms
                        Coins.loadAlgorithms()
                    
                        # Load miners
                        Miners.loadMiners()
                    
                        # Load event actions and triggers
                        Triggers.loadTriggers()
                        Actions.loadActions()
                    
                        # Load workers
                        workers = Wkr.loadWorkers()
                        
                        # Start watchdog and start running
                        Watchdog.eatMainThread() {
                            # Start mining
                            @@rootLog.info("Starting mine cycle.")
                            runMainLoop(workers)
                        }
                    else
                        @@rootLog.fatal("No workers were loaded.  Unable to mine.")
                    end
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

