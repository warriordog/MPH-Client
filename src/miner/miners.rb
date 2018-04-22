#--------------
# Coins miners
#--------------

require 'util/log'
require 'config'

module Miners
    # Module logger
    @@logger = Log.createLogger("Miners")
    
    # Hash of ids -> miner
    @@miners = {}
    
    class Miner
        def initialize(id, name, path, exec, args, remap)
            @id = id
            @name = name
            @path = path
            @exec = exec
            @args = args
            
            # Map of symbol -> string
            @remapCoins = remap
            
            # If remap is nil then set default
            @remapCoins ||= {}
        end
        
        attr_reader :id, :name, :path, :exec
        
        def args(job)
            # Not the most efficient way to do this, but this method is infrequently called 
            return @args
                .gsub("#TIMEOUT#", Config.settings[:switch_interval].to_s)
                .gsub("#HOST#", job.host.addr.to_s)
                .gsub("#PORT#", job.host.port.to_s)
                .gsub("#WORKER_ID#", job.worker.id.to_s)
                .gsub("#ACCOUNT#", Config.settings[:account].to_s)
                .gsub("#COIN#", self.remapCoin(job.coin.id.to_s))
                .gsub("#ALGORITHM#", job.algorithm.id.to_s)
            ;
        end
        
        def remapCoin(inCoin)
            outCoin = @remapCoins[inCoin.to_sym] # set outcoin to remap coin
            outCoin ||= inCoin # if outcoin is nil (no remap coin) then set to input
            
            if (inCoin != outCoin)
                Miners.logger.debug {"Remapping #{inCoin} to #{outCoin} for #{@id}"}
            end
            
            return outCoin
        end
        
        def self.createFromJSON(id, json)
            return Miner.new(id, json[:name], json[:path], json[:exec], json[:args], json[:remap_coins])
        end
        
    end
    
    # Parses a miner and adds it to the miner hash
    def self.loadMiner(id, json)
        miner = Miner.createFromJSON(id, json)
        
        # Add to hash
        if (@@miners[miner.id] != nil)
            @@logger.warn("Duplicate miner #{miner.id}.")
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
        return @@logger
    end
end
