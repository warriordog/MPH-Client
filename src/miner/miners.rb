#--------------
# Coins miners
#--------------

require 'util/log'
require 'config'
require 'util/args'
require 'util/application'

module Miners
    # Module logger
    @@logger = nil
    
    # Hash of ids -> miner
    @@miners = {}
    
    # Miner-specific application
    class Miner
        def initialize(id, app, remap)
            @id = id
            @app = app
            
            # Map of symbol -> string
            @remapCoins = remap
        end
        
        attr_reader :id, :app, :remapCoins
        
        def args(context)
            return app.args(context)
        end
        
        def remapCoin(inCoin)
            outCoin = @remapCoins[inCoin.to_sym] # set outcoin to remap coin
            
            if (outCoin != nil)
                Miners.logger.debug {"Remapping #{inCoin} to #{outCoin} for #{@id}"}
                return outCoin
            else
                return inCoin
            end
        end
        
        def workingDir()
            return app.workingDir
        end
        
        def executable()
            return app.executable
        end
        
        def logge()
            return app.logger
        end
        
        def self.createFromJSON(id, json)
            if (json.include? :app)
                app = Application.getApp(json[:app])
                if (app != nil)
                    if (json.include? :remap_coins)
                        remap = json[:remap_coins]
                    else
                        remap = {}
                    end
            
                    return Miner.new(id, app, remap)
                else
                    logger.warn "Application '#{json[:app]}' is missing.  Miner '#{id}' will not be created."
                end
            else
                logger.warn "Miner '#{id}' is missing an application.  It will not be created."
            end
            
            return nil
        end
        
    end
    
    # Parses a miner and adds it to the miner hash
    def self.loadMiner(id, json)
        miner = Miner.createFromJSON(id, json)
        
        # Add to hash
        if (@@miners[miner.id] != nil)
            Miners.logger.warn("Duplicate miner #{miner.id}.")
        end
        @@miners[miner.id] = miner
    end
    
    # Loads all miners from config
    def self.loadMiners()
        Config.miners.each {|id, json| loadMiner(id.to_s, json)}
    end
    
    def self.miners()
        return @@miners
    end
    
    def self.logger()
        if (@@logger == nil)
            @@logger = Log.createLogger("Miners")
        end
        return @@logger
    end
end
