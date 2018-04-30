#---------------
# Worker groups
#---------------

require 'config'
require 'util/log'
require 'miner/coins'
require 'miner/miners' 
require 'miner/event/events'
require 'miner/event/triggers'
require 'util/application'

module Wkr

    # Module logger
    @@logger = nil

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
            if (miner != nil)
                return WorkerMiner.new(miner, json[:rate])
            else
                Coins.logger.warn("Missing miner: '#{id}'.")
            end
        end
    end

    # An algorithm supported by a specific worker
    class WorkerAlgorithm
        def initialize(algorithm, wkrMiners, whitelist, blacklist)
            @algorithm = algorithm
            
            # Sort by descending rate
            @wkrMiners = wkrMiners.sort() {|m1, m2| m2.rate <=> m1.rate}
            
            @whitelistCoins = whitelist
            @blacklistCoins = blacklist
        end
        
        attr_reader :algorithm, :wkrMiners, :whitelistCoins, :blacklistCoins
        
        def supportsCoin?(coin)
            # first make sure algo matches
            if (@algorithm.supportsCoin? coin)
                
                # if there is a whitelist and this coin is not in it
                if (@whitelistCoins != nil && !@whitelistCoins.include?(coin))
                    Wkr.logger.debug {"Whitelist excluding #{coin}."}
                    return false
                end
                
                # if there is a blacklist and this coin is in it
                if (@blacklistCoins != nil && @blacklistCoins.include?(coin))
                    Wkr.logger.debug {"Blacklist excluding #{coin}."}
                    return false
                end
                
                # algo supports and lists allow
                return true
            else
                # not supported
                return false
            end
            
        end
        
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
                return WorkerAlgorithm.new(alg, wkrMiners, json[:whitelist_coins], json[:blacklist_coins])
            end
        end
    end

    class WorkerJob
        def initialize(worker, algorithm, coin, miner, host, hashrate, profit)
            @worker = worker
            @algorithm = algorithm
            @coin = coin
            @miner = miner
            @host = host
            @hashrate = hashrate    # Hashrate of this job
            @profit = profit        # Profit of this job (per day)
            @executor = Application::Executor.new(miner.app)
        end
        
        attr_reader :worker, :algorithm, :coin, :miner, :executor, :host, :hashrate, :profit
        
        def start()
            if (!@worker.paused)
                context = @worker.getAppEnvironment()
            
                # Run algorithm
                @executor.start(context)
            end
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
        
        def pause()
            self.stop()
        end
        
        def resume()
            self.start()
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
        def initialize(name, id, profitField, algorithms, percentProfitThreshold, events)
            @name = name
            @id = id
            @profitField = profitField
            @percentProfitThreshold = percentProfitThreshold.to_f
            
            # Map algorithm ID -> workerAlgorithm@algos[Coins.Coins[statCoin[:coin_name]]
            @algos = algorithms
            @logger = Log.createLogger("worker/" + @id)
            
            @events = events
            
            @currentJob = nil
            
            # map of symbol id -> map of (id object -> proc)
            @listeners = Hash.new { |h, k| h[k] = {} } # hash default values are unique hashes
            
            # If true, don't mine
            @paused = false
        end
        
        # Add getters
        attr_reader :name, :id, :profitField, :algos, :logger, :currentJob, :events, :paused
        
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
                    
                    # Raw profit (BTC/day per Gh/s)
                    rawProfit = statCoin[@profitField.to_sym].to_f # BTC / (Gh/s) / day

                    # This is way simpler than I thought
                    minerProfit = rawProfit * minerGHperS

                    # Debug print profit
                    @logger.debug {"calculated profit for #{statCoin[:coin_name]} on #{miner.miner.id}: #{minerProfit}"}
                    
                    return minerProfit.to_f
                else
                    @logger.error("No miners for coin #{statCoin[:coin_name]}")
                end
            else
                # Should not happen, but -1 profit if we don't have an algorithm for that coin
                @logger.warn("Filter did not exclude coin '#{statCoin[:coin_name]}' from worker '#{@id}'")
            end
            
            # If we could not calculate profit for some reason, then profit is -1
            return -1.0
        end
        
        # Switch currently running algorithm based on current profit statistics
        def switchAlgo(stats)
            # only include coins that we have miners for, then sort by descending profit
            statCoins = stats
                .select {|statCoin| @algos.any?{|id, wkrAlgo| wkrAlgo.supportsCoin?(statCoin[:coin_name])}}
                .each {|statCoin| statCoin[:CalculatedProfit] = calcProfit(statCoin)}
                .sort {|a, b| b[:CalculatedProfit] <=> a[:CalculatedProfit]}
            ;
            
            # Make sure there was at least one good coin
            if (!statCoins.empty?)
                # First should be most profitable
                statCoin = statCoins[0]
                coinName = statCoin[:coin_name]
                
                # Lokup matching coin
                coin = Coins.coins[coinName]
                
                # Make sure profit increase exceeds threshold
                currentStatCoin = statCoins.find{|sCoin| (@currentJob != nil) && (sCoin[:coin_name] == @currentJob.coin.id)}
                if (currentStatCoin == nil || (statCoin[:CalculatedProfit] >= (currentStatCoin[:CalculatedProfit] * @percentProfitThreshold)))
                    
                    # Get WorkerAlgorithm for this coin
                    wkrAlgo = @algos[coin.algorithm.id]
                    # Get miner for this worker/algorithm (miners are sorted by hashrate already)
                    wkrMiner = wkrAlgo.wkrMiners[0]
                    # Get best miner for this coin
                    miner = wkrMiner.miner
                    
                    # Create host for this task
                    host = Host.new(statCoin[:direct_mining_host], statCoin[:port])
                    
                    # Start mining only if the task parameters have changed
                    if (@currentJob == nil || !@currentJob.same?(wkrAlgo.algorithm, coin, miner, host))
                    
                        # Stop current job, if there is one
                        if (@currentJob != nil)
                            @currentJob.stop()
                            lastCoin = @currentJob.coin
                        else
                            lastCoin = nil
                        end
                        
                        # Set up new job
                        @currentJob = WorkerJob.new(self, wkrAlgo.algorithm, coin, miner, host, wkrMiner.rate, statCoin[:CalculatedProfit])
                        @currentJob.start()
                        
                        # Fire coin switch event
                        fireEvent(:switch_coin, {'TASK.LAST_COIN.ID' => lastCoin&.id, 'TASK.LAST_COIN.ALGO' => lastCoin&.algorithm&.id})
                        
                        # Fire algo switch event
                        if (lastCoin == nil || lastCoin.algorithm != @currentJob.coin.algorithm)
                            fireEvent(:switch_algo, {'TASK.LAST_COIN.ALGO' => lastCoin&.algorith&.id})
                        end
                    
                        # lastCoin is nil if there was no previous job
                        if (lastCoin == nil)
                            fireEvent(:start_mining, {})
                        end
                    else
                        @logger.debug("Not changing coins")
                    end
                else
                    @logger.debug {"Not switching from #{@currentJob.coin.id} to #{coin.id} (not enough increase)."}
                end
            else
                @logger.error("No valid coins for worker #{@name}, not switching!")
            end
        end
        
        # Stop mining (if mining)
        def stopMining()
            # Fire mining stop events
            fireEvent(:stop_mining, {'STOP_MINING.WAS_MINING' => (@currentJob != nil)})
        
            if (@currentJob != nil)
                @currentJob.stop()
                @currentJob = nil
            end
        end
        
        # Add a listener
        def addListener(signal, id, &block)
            @listeners[signal][id] = block
        end
        
        # Remove a listener
        def removeListener(id)
            @listeners.delete_if {|sigKey, sigVal| sigVal.find {|listenerId, listener| listenerId == id}}
        end
        
        # Prepares this worker to start mining
        def startup()
            @logger.debug {"Starting up worker."}
            
            # Apply triggers
            @events.each {|event| event.trigger.addToWorker(self, event)}
            
            # Call startup listeners
            fireEvent(:startup, {})
        end
        
        # Prepares this worker to stop mining
        def shutdown()
            @logger.debug {"Shutting down worker."}
            
            # Call shutdown listeners
            fireEvent(:shutdown, {})
            
            # Detach triggers
            @events.each {|event| event.trigger.removeFromWorker(self)}
        end
        
        # Pauses mining
        def pauseMining()
            @logger.debug "Pausing mining."
            @paused = true
            if (@currentJob != nil)
                @currentJob.pause
            end
        end
        
        # Resumes paused mining
        def resumeMining()
            @logger.debug "Resuming mining."
            @paused = false
            if (@currentJob != nil)
                @currentJob.resume
            end
        end
        
        # Gets a set of context variables for an app
        def getAppEnvironment()
            return {
                'CONFIG.NETWORK_TIMEOUT' => Config.settings[:reconnect_interval].to_s,
                'CONFIG.ACCOUNT' => Config.settings[:account].to_s,
                'JOB.HOST' => "#{@currentJob&.host&.addr}:#{@currentJob&.host&.port}",
                'JOB.HOST.NAME' => @currentJob&.host&.addr.to_s,
                'JOB.HOST.PORT' => @currentJob&.host&.port.to_s,
                'JOB.WORKER.ID' => @id.to_s,
                'JOB.WORKER.USERNAME' => "#{Config.settings[:account]}.#{@id}",
                'JOB.COIN.ID' => @currentJob&.miner&.remapCoin(@currentJob&.coin&.id.to_s),
                'JOB.COIN.ALGO' => @currentJob&.algorithm&.id.to_s,
            }
        end
        
        # Adds global vars to a hash
        def injectGlobalVars(vars)
            vars['WORKER.ID'] = @id
            
            if (@currentJob != nil) 
                vars['TASK.ACTIVE'] = true
                vars['TASK.PROFIT'] = @currentJob.profit
                vars['TASK.COIN.ID'] = @currentJob.coin.id
                vars['TASK.COIN.ALGO'] = @currentJob.coin.algorithm.id
                vars['TASK.MINER.ID'] = @currentJob.miner.id
                vars['TASK.MINER.RATE'] = @currentJob.hashrate
            else
                vars['TASK.ACTIVE'] = false
            end
        end
        
        # Fires an event with the specified variables
        def fireEvent(eventId, vars)
            # Vars cannot be nil
            if (vars == nil)
                vars = {}
            end
        
            # Add common, always-present variables
            injectGlobalVars(vars)
        
            @listeners[eventId].each {|id, block|
                block.call(self, vars)
            }
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
            
            # Create events
            events = []
            if (json.include? :events)
                json[:events].each {|eventJson|
                    event = Events::Event.createFromJSON(eventJson)
                    if (event != nil)
                        events << event
                    end
                }
            end
            
            # Create worker
            worker = Worker.new(json[:name], id, "profit", algs, json[:percentProfitThreshold], events)
            
            return worker;
        end
    end

    def self.logger()
        if (@@logger == nil)
            @@logger = Log.createLogger("Worker")
        end
        return @@logger
    end
    
    # Loads all workers from config file
    def self.loadWorkers()
        workers = []
        Config.workers.each {|id, wkr| workers << Worker.createFromJSON(id.to_s, wkr)}
        return workers
    end
end
