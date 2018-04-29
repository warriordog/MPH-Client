#----------------------
# Coins and algorithms
#----------------------

require 'util/log'

module Coins
    # Module logger (lazy created to make sure defaults are set)
    @@logger = nil
    
    # Hash of ids -> algorithms
    @@algorithms = {}
    
    # Hash of ids -> coins
    @@coins = {}
    
    # A crypto algorithm
    class Algorithm
        def initialize(id, name)
            @id = id
            @name = name
            @coins = []
        end
        
        attr_reader :id, :name, :coins
        
        def addCoin(coin)
            @coins << coin
        end
        
        def supportsCoin?(coin)
            # Check if contains coin or coin as a name
            return @coins.include?(coin) || @coins.include?(Coins.coins[coin])
        end
        
        def self.createFromJSON(id, json)
            alg = Algorithm.new(id, json[:name])
            json[:coins].each {|coinId, coinJson| alg.addCoin(Coin.createFromJSON(coinId.to_s, coinJson, alg))}
            return alg
        end
    end
    
    # A coin
    class Coin
        def initialize(id, name, algorithm)
            @id = id
            @name = name
            @algorithm = algorithm
        end
        
        attr_reader :id, :name, :algorithm
        
        def self.createFromJSON(id, json, algorithm)
            return Coin.new(id, json[:name], algorithm)
        end
    end

    def self.loadAlgorithm(id, json)
        # Create algorithm
        alg = Algorithm.createFromJSON(id, json)
        
        # Add to hash
        if (Coins.algorithms[alg.id] != nil)
            Coins.logger.warn("Duplicate algorithm #{alg.id}.")
        end
        Coins.algorithms[alg.id] = alg
        
        # Add cointained coins
        alg.coins.each {|coin|
            if (Coins.coins[coin.id] != nil)
                Coins.logger.warn("Duplicate coin #{coin.id}.")
            end
            Coins.coins[coin.id] = coin
        }
    end
    
    def self.loadAlgorithms()
        Config.algorithms.each{|id, json| loadAlgorithm(id.to_s, json)}
    end
    
    def self.algorithms()
        return @@algorithms
    end
    
    def self.logger()
        if (@@logger == nil)
            @@logger = Log.createLogger("Coins")
        end
        return @@logger
    end
    
    def self.coins()
        return @@coins
    end
end


