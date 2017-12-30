#----------------------
# Coins and algorithms
#----------------------

require 'util/log'

module Coins
    # Module logger
    @@logger = Log.createLogger("Coins", toFile: true, toConsole: true)
    
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
        
        def self.createFromJSON(json)
            alg = Algorithm.new(json[:id], json[:name])
            json[:coins].each {|coin| alg.addCoin(Coin.createFromJSON(coin, alg))}
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
        
        def self.createFromJSON(json, algorithm)
            return Coin.new(json[:id], json[:name], algorithm)
        end
    end

    def self.loadAlgorithm(json)
        # Create algorithm
        alg = Algorithm.createFromJSON(json)
        
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
        Config.algorithms.each{|json| loadAlgorithm(json)}
    end
    
    def self.algorithms()
        return @@algorithms
    end
    
    def self.logger()
        return @@logger
    end
    
    def self.coins()
        return @@coins
    end
end


