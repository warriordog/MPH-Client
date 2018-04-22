#---------------
# Worker groups
#---------------

require 'config'
require 'util/log'
require 'miner/executor'
require 'miner/coins'
require 'miner/miners'

module Wkr

    # Module logger
    @@logger = Log.createLogger("Workers")

    # Hash of ids -> workers
    @@Workers = {}

    # A miner supported by a specific worker
    class WorkerMiner
        def initialize(miner, rate)
            @miner = miner
            @rate = rate.to_i
        end
        
        attr_reader :miner, :rate
        
        def self.createFromJSON(id, json)
            # Look up miner
            miner = Miners.miners[id]
            if (miner == nil)
                Coins.logger.warn("Missing miner: #{id}")
            end
            
            return WorkerMiner.new(miner, json[:rate])
        end
    end

    # An algorithm supported by a specific worker
    class WorkerAlgorithm
        def initialize(algorithm, wkrMiners)
            @algorithm = algorithm
            
            # Sort by descending rate
            @wkrMiners = wkrMiners.sort() {|m1, m2| m2.rate <=> m1.rate}
        end
        
        attr_reader :algorithm, :wkrMiners
        
        def self.createFromJSON(id, json)
            # Load miners
            wkrMiners = []
            json[:miners].each {|minerId, minerJson| wkrMiners << WorkerMiner.createFromJSON(minerId.to_s, minerJson)}
        
            # Look up algorithm
            alg = Coins.algorithms[id]
            if (alg == nil)
                Coins.logger.warn("Missing algorithm: #{id}")
                return nil
            else
                return WorkerAlgorithm.new(alg, wkrMiners)
            end
        end
    end

    class WorkerJob
        def initialize(worker, algorithm, coin, miner, host)
            @worker = worker
            @algorithm = algorithm
            @coin = coin
            @miner = miner
            @host = host
            @executor = nil
        end
        
        attr_reader :worker, :algorithm, :coin, :miner, :executor, :host
        
        def start()
            # Run algorithm
            @executor = Executor.new()
            @executor.start(self)
        end
        
        def running?()
            return @executor != nil && @executor.alive?()
        end
        
        def same?(algo, coin, miner, host)
            return running? && algo == @algorithm && coin == @coin && miner == @miner && host == @host
        end
        
        def stop()
            if (running?)
                @executor.stop()
            end
        end
    end
    
    class Host
        def initialize(addr, port)
            @addr = addr
            @port = port
        end
        
        attr_reader :addr, :port
        
        def ==(other)
            return other.addr == @addr && other.port == @port
        end
    end

    class Worker
        def initialize(name, id, profitField, algorithms)
            @name = name
            @id = id
            @profitField = profitField
            
            # Map algorithm ID -> workerAlgorithm@algos[Coins.Coins[statCoin[:coin_name]]
            @algos = algorithms
            @logger = Log.createLogger("worker/" + @id)
            
            @currentJob = nil
        end
        
        # Add getters
        attr_reader :name, :id, :profitField, :algos, :logger, :currentJob
        
        # Find the profit for a specified coin
        def calcProfit(statCoin)
            # Get algorithm for coin name, then look up WorkerAlgorithm by ID
            algo = @algos[Coins.coins[statCoin[:coin_name]].algorithm.id]
            if (algo != nil)
                wkrMiners = algo.wkrMiners
                if (!wkrMiners.empty?)
                
                    # Calculate best miner hashrate
                    miner = wkrMiners[0] # wkrMiners are sorted with most profitable first
                    minerHperS = miner.rate.to_f # Our rate in H/s
                    minerGHperS = minerHperS / 1000000000.0 # Our rate in Gh/s
                    
                    # Calculate pool hashrate
                    poolMHperS = MPH.parseRateMh(statCoin[:pool_hash]) # Pool rate in Mh/s
                    poolGHperS = poolMHperS / 1000.0 # Pool rate in GH/s

                    # Calculate pool profit
                    rawProfit = statCoin[@profitField.to_sym].to_f # BTC / (Gh/s) / day
                    poolProfit = rawProfit * poolGHperS # rawProfit * (Gh/s) * 1 day
                    
                    # Calculate miner profit
                    # TODO add our hashrate if we aren't already mining
                    hashratePercent = minerGHperS / poolGHperS  # percent of pool hashrate that is mine
                    minerProfit = poolProfit * hashratePercent
                    
                    # Debug print profit
                    @logger.debug {"calculated profit for #{statCoin[:coin_name]} on #{miner.miner.id}: #{minerProfit}"}
                    
                    return minerProfit
                else
                    @logger.error("No miners for coin #{statCoin[:coin_name]}")
                end
            else
                # Should not happen, but -1 profit if we don't have an algorithm for that coin
                @logger.warn("Filter did not exclude coin '#{statCoin[:coin_name]}' from worker '#{@id}'")
            end
            
            # If we could not calculate profit for some reason, then profit is -1
            return -1
        end
        
        # Switch currently running algorithm based on current profit statistics
        def switchAlgo(stats)
            # only include coins that we have miners for, then sort by descending profit
            statCoins = stats
                .select {|statCoin| @algos.any?{|id, wkrAlgo| wkrAlgo.algorithm.supportsCoin?(statCoin[:coin_name])}}
                .each {|statCoin| statCoin[:CalculatedProfit] = calcProfit(statCoin)}
                .sort {|a, b| b[:CalculatedProfit] <=> a[:CalculatedProfit]}
            ;
            
            # Debug print profit
            #statCoins.each {|statCoin|
            #    statProfit = statCoin[@profitField.to_sym]
            #    wkrMiners = @algos[Coins.coins[statCoin[:coin_name]].algorithm.id].wkrMiners
            #    wkrMiners.each {|m| 
                    #gRate = m.rate.to_f / 1000000000.0
                    #prof = m.rate.to_f * statProfit
                    #gProf = gRate * statProfit
                    #@logger.debug {"Profit for #{statCoin[:coin_name]} on #{m.miner.id}:  #{statProfit} * #{m.rate}H/s (#{gRate}GH/s) = #{prof} (#{gProf}))"}
            #        
            #    }
            #}
            
            # Make sure there was at least one good coin
            if (!statCoins.empty?)
                # First should be most profitable
                statCoin = statCoins[0]
                coinName = statCoin[:coin_name]
                
                # Lokup matching coin
                coin = Coins.coins[coinName]
                # Get WorkerAlgorithm for this coin
                wkrAlgo = @algos[coin.algorithm.id]
                # Get best miner for this coin
                miner = wkrAlgo.wkrMiners[0].miner
                
                # Create host for this task
                host = Host.new(statCoin[:direct_mining_host], statCoin[:port])
                
                # Start mining only if the task parameters have changed
                if (@currentJob == nil || !@currentJob.same?(wkrAlgo.algorithm, coin, miner, host))
                    # start job
                    @logger.info("Switching to #{coinName}")
                    
                    # Stop current job, if there is one
                    if (@currentJob != nil)
                        @currentJob.stop()
                    end
                    
                    # Set up new job
                    @currentJob = WorkerJob.new(self, wkrAlgo.algorithm, coin, miner, host)
                    @currentJob.start()
                else
                    @logger.debug("Not changing coins")
                end
            else
                @logger.error("No valid coins for worker #{@name}, not switching!")
            end
        end
        
        # Stop mining (if mining)
        def stopMining()
            if (@currentJob != nil)
                @currentJob.stop()
                @currentJob = nil
            end
        end
        
        # Load from json
        def self.createFromJSON(id, json)
            # Create WorkerAlgorithms
            algs = {}
            json[:algorithms].each {|algId, algJson| 
                wkrAlg = WorkerAlgorithm.createFromJSON(algId.to_s, algJson)
                if (wkrAlg != nil)
                    algs[wkrAlg.algorithm.id] = wkrAlg
                end
            }
            
            # Create worker
            return Worker.new(json[:name], id, "profit", algs)
        end
    end

    # Loads all workers from config file
    def self.loadWorkers()
        workers = []
        Config.workers.each {|id, wkr| workers << Worker.createFromJSON(id, wkr)}
        return workers
    end
end
