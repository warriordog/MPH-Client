#---------------
# Worker groups
#---------------

require_relative('executor')

module Wkr
    class Miner
        def initialize(name, path, exec, args)
            @name = name
            @path = path
            @exec = exec
            @args = args
        end
        
        attr_reader :name, :path, :exec
        
        def args(worker, coin)
            return @args
                .gsub("$$TIMEOUT", Config.settings[:switch_interval].to_s)
                .gsub("$$HOST", coin[:direct_mining_host].to_s)
                .gsub("$$PORT", coin[:port].to_s)
                .gsub("$$WORKER_ID", worker.id.to_s)
                .gsub("$$ACCOUNT", Config.settings[:account].to_s)
            ;
        end
    end

    class Algorithm
        def initialize(name, coins, rate, miner)
            @name = name
            @coins = coins
            @rate = rate
            
            @miner = Wkr.createMiner(miner)
        end
        
        attr_reader :name, :coins, :rate, :miner
    end

    class Worker
        def initialize(name, id, profitField, algorithms)
            @name = name
            @id = id
            @profitField = profitField
            
            @algos = Wkr.loadAlgorithms(algorithms)
            @logger = Log.createLogger("worker." + @name, true, true)
            
            @executor = nil
        end
        
        # Add getters
        attr_reader :name, :id, :profitField, :algos, :logger, :executor
        
        # Find the profit for a specified coin
        def calcProfit(coin)
            algo = @algos.find {|alg| alg.coins.contains(coin[:coin_name])}
            if (algo != nil)
                return coin[@profitField] * algo.rate;
            else
                # Should not happen, but -1 profit if we don't have an algorithm for that coin
                @logger.warn("Filter did not exclude coin '#{coin[:coin_name]}' from worker '#{@id}'")
                return -1
            end
        end
        
        # Switch currently running algorithm based on current profit statistics
        def switchAlgo(stats)
            # only include coins that we have miners for, then sort by descending profit
            coins = stats.select {|coin| @algos.any?{|algo| algo.coins.include?(coin[:coin_name])}}.sort {|a, b| calcProfit(b) <=> calcProfit(a)}
            if (coins.length > 0)
                # First should be most profitable
                coin = coins[0]
                coinName = coin[:coin_name]
                algo = @algos.find {|alg| alg.coins.include?(coinName)}
                
                # Run algorithm
                # TODO get rid of duplicate code
                if (@executor == nil)
                    @logger.info("Switching to #{coinName}")
                    @executor = Executor.new()
                    @executor.start(algo, self, coin)
                elsif (@executor.algorithm != algo)
                    @logger.info("Switching to #{coinName}")
                    @executor.stop()
                    @executor = Executor.new()
                    @executor.start(algo, self, coin)
                end
            else
                puts "Error: no valid coins for worker #{@name}!"
            end
        end
        
        # Stop mining (if mining)
        def stopMining()
            if (@executor != nil)
                @executor.stop()
                @executor = nil
            end
        end
    end

    def self.loadWorkers(arr)
        workers = []
        arr.each {|wkr| workers << Worker.new(wkr[:name], wkr[:id], wkr[:profit_field], wkr[:algorithms])}
        return workers
    end

    def self.loadAlgorithms(arr)
        algs = []
        arr.each {|alg| algs << Algorithm.new(alg[:name], alg[:coins], alg[:rate], alg[:miner])}
        return algs
    end

    def self.createMiner(hash)
        return Miner.new(hash[:name], hash[:path], hash[:exec], hash[:args])
    end
end
