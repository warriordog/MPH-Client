#
# total_balance.rb
# Adds up a user's total balance of all coins
# 

require 'optparse'
require 'json'
require 'net/http'

class Coin
    def initialize(name, confirmed, unconfirmed, aeConfirmed, aeUnconfirmed, exchange)
        @name = name
        @balConfirmed = confirmed
        @balUnconfirmed = unconfirmed
        @aeConfirmed = aeConfirmed
        @aeUnconfirmed = aeUnconfirmed
        @onExchange = exchange
        
        @exchangeRate = 0
        @exchangeUnit = nil
    end
    
    attr_reader :name, :balConfirmed, :balUnconfirmed, :aeConfirmed, :aeUnconfirmed, :onExchange, :exchangeRate, :exchangeUnit
    
    def total()
        return @balConfirmed + @balUnconfirmed + @aeConfirmed + @aeUnconfirmed + @onExchange
    end
    
    def totalValue()
        return total() * @exchangeRate
    end
    
    def updateExchangeRate(cgCoins, fiat)
        cgCoin = cgCoins[@name.downcase()]
        if (cgCoin != nil)
            rates = JSON.parse(Net::HTTP.get(URI("https://www.coingecko.com/price_charts/#{cgCoin.id}/#{fiat}/24_hours.json")))['stats']
            if (rates != nil)
                # Last rate, second value
                rate = rates[-1][1]
                if (rate != nil)
                    @exchangeRate = rate
                else
                    puts "Bad exchange data received for #{@name}"
                end
            else
                puts "Error getting exchange history for #{@name}"
            end
        else
            puts "Missing MPH -> CG coin id mapping for #{@name}"
        end
    end
    
    def self.createFromJSON(json)
        return Coin.new(json['coin'], json['confirmed'], json['unconfirmed'], json['ae_confirmed'], json['ae_unconfirmed'], json['exchange'])
    end
end

class Balance
    def initialize(coins)
        # hash of coin name -> coin
        @coins = coins
    end
    
    attr_reader :coins
    
    def self.createFromJSON(arr)
        coins = {}
        arr.each {|coinJson|
            coin = Coin.createFromJSON(coinJson)
            coins[coin.name] = coin
        }
        return Balance.new(coins)
    end
    
    def self.createFromMPH(apiKey)
        # send request
        json = Net::HTTP.get(URI("https://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=#{apiKey}"))
        
        # Parse json
        resp = JSON.parse(json)
        
        # Check for success
        json = resp['getuserallbalances']
        if (json != nil)
            return self.createFromJSON(json['data'])
        else
            return nil
        end
    end
end

class CGCoin
    def initialize(symbol, name, id)
        @symbol = symbol
        @name = name
        @id = id
    end
    
    attr_reader :symbol, :name, :id
    
    def self.createFromJSON(json)
        name = json['name'].downcase().gsub(' ', '-')
        return CGCoin.new(json['symbol'], name, json['id'])
    end
    
    def self.createAllFromJSON(json)
        coins = {}
        json.each{|coinJson|
            coin = self.createFromJSON(coinJson)
            coins[coin.name.downcase()] = coin
        }
        return coins
    end
    
    def self.createAllFromFile(path)
        return self.createAllFromJSON(JSON.parse(File.read(path)))
    end
end

# Read config
if (ARGV.length >= 2)
    apiKey = ARGV[0]

    # Read CoinGecko exchange map
    cgCoins = CGCoin.createAllFromFile(ARGV[1])

    # Optional settings
    options = {}
    options[:ignored_coins] = []
    options[:fiat] = "USD"
    options[:fuzzy] = false
    options[:blurry] = false
    options[:individual] = false
    options[:coin_precision] = 10
    options[:fiat_precision] = 2
    options[:tidy] = false

    # Read options if avaialable
    for i in (2...ARGV.length)
        arg = ARGV[i]
        
        if (arg == "-fuzzy")
            options[:fuzzy] = true
        elsif (arg == "-blurry")    
            options[:blurry] = true
        elsif (arg == "-individual")    
            options[:individual] = true
        elsif (arg == "-tidy")    
            options[:tidy] = true
        elsif (arg.start_with?("-ignore"))
            options[:ignored_coins] << arg.sub("-ignore", "")
        elsif (arg.start_with?("-fiat"))
            options[:fiat] << arg.sub("-fiat", "")
        elsif (arg.start_with?("-coin_precision"))
            options[:coin_precision] << arg.sub("-coin_precision", "")
        elsif (arg.start_with?("-fiat_precision"))
            options[:fiat_precision] << arg.sub("-fiat_precision", "")
        else
            puts "Unknown option: #{arg}"
        end
    end
    
    # Get data from MPH
    balance = Balance.createFromMPH(apiKey)
    if (balance != nil)
        
        # Get exchange rates from CoinGecko
        balance.coins.values.each {|coin|
            # If coin is ignored, then exchange rate will default to zero and it will not be counted
            if (!options[:ignored_coins].any? {|ignoredCoin| ignoredCoin.downcase() == coin.name.downcase()})
                coin.updateExchangeRate(cgCoins, options[:fiat].downcase())
            end
        }
        
        # Print individual values
        if (options[:individual])
            balance.coins.values.each {|coin|
                # Check if coin is ignored
                if (coin.exchangeRate > 0)
                    if (!options[:tidy])
                        puts "#{coin.name}: #{coin.total().round(options[:coin_precision])} #{cgCoins[coin.name].symbol} == #{coin.totalValue().round(options[:fiat_precision])} #{options[:fiat]}"
                    else
                        printf("%0.#{options[:coin_precision]}f %s == %0.#{options[:fiat_precision]}f %s\n", coin.total(), cgCoins[coin.name].symbol, coin.totalValue(), options[:fiat])
                    end
                else
                    if (!options[:tidy])
                        puts "#{coin.name}: #{coin.total().round(options[:coin_precision])} #{cgCoins[coin.name].symbol} ignored."
                    else
                        printf("%0.#{options[:coin_precision]}f %s ignored.\n", coin.total(), cgCoins[coin.name].symbol)
                    end
                end
            }
        end
        
        # Sum total values
        total = balance.coins.values.inject(0){|sum, coin|
            sum + coin.totalValue()
        }
        
        # Print total value
        if (!options[:tidy])
            puts "Total value: #{total} #{options[:fiat]}"
        else
            printf("Total %0.#{options[:fiat_precision]}f %s\n", total, options[:fiat])
        end
    else
        puts "Error getting balance information from MPH, check your API key and internet connection."
    end
else
    puts "Usage: ruby total_balance.rb <API_key> <CoinGecko_id_list> [options]"
    puts "Options:"
    puts "  -ignore<COIN>            - Don't count a specified coin"
    puts "  -fiat<CURRENCY>          - Set fiat currency or coin (default USD)"
    puts "  -fuzzy                   - Use average of last day for conversions"
    puts "  -blurry                  - Use average of last week for conversions"
    puts "  -individual              - Print value of each coin"
    puts "  -coin_precision<DIGITS>  - Number of digits to display for coin values (default 10)"
    puts "  -fiat_precision<DIGITS>  - Number of digits to display for fiat values (default 2)"
    puts "  -tidy                    - Compact output to stack nicely in a terminal"
end