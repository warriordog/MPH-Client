#
# total_balance_coinbase.rb
# Adds up a user's total balance of all coins using data from CoinBase
# 

require 'json'
require 'net/http'

# Mapping of coin name to symbol
$coin_symbol_map = {'bitcoin' => 'BTC', 'bitcoin-cash' => 'BCH', 'ethereum' => 'ETH', 'litecoin' => 'LTC'}

class Coin
    def initialize(name, confirmed, unconfirmed, aeConfirmed, aeUnconfirmed, exchange)
        @name = name
        @balConfirmed = confirmed
        @balUnconfirmed = unconfirmed
        @aeConfirmed = aeConfirmed
        @aeUnconfirmed = aeUnconfirmed
        @onExchange = exchange
        
		# Exchange rate in coin / BTC
        @exchangeRate = 0
    end
    
    attr_reader :name, :balConfirmed, :balUnconfirmed, :aeConfirmed, :aeUnconfirmed, :onExchange
	attr_accessor :exchangeRate
    
    def total()
        return @balConfirmed + @balUnconfirmed + @aeConfirmed + @aeUnconfirmed + @onExchange
    end
    
	# In BTC
    def totalValueBTC()
        return total() * @exchangeRate
    end
	
	# Total value in some other coin
	def totalValueIn(outCoin)
		btcToOut = 1 / outCoin.exchangeRate()
	
		btcValue = self.totalValueBTC()
		outValue = btcValue * btcToOut
		
		return outValue
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
	
	def updateExchangeRates()
		json = nil
		begin
			# send request
			json = JSON.parse(Net::HTTP.get(URI("https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics")))
		rescue Exception => e
			puts "Network error: #{e}"
			return
		end
		
		# check for success
		if (json['success'])
			# get data
			data = json['return']
			
			# Update exchange rates
			@coins.values.each {|coin| 
				dataCoin = data.find {|entry| coin.name == entry['coin_name']}
				
				if (dataCoin != nil)
					if (dataCoin['highest_buy_price'] != nil)
						coin.exchangeRate = dataCoin['highest_buy_price']
					else
						puts "API inconsistency: #{coin.name} has no exchange rate."
					end
				else
					puts "API inconsistency: #{coin.name} has been mined but has no data."
				end
			}
		end
	end
	
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

def getCoinbaseRate(coin)
	# Get coin symbol
	coinId = $coin_symbol_map[coin]
	if (coinId != nil)
		json = nil
		begin
			# send request
			json = JSON.parse(Net::HTTP.get(URI("https://api.coinbase.com/v2/prices/#{coinId}-USD/spot")))
		rescue Exception => e
			puts "Network error: #{e}"
			return 0
		end
		# get data
		data = json['data']
		
		# Check for success
		if (data != nil)
			return data['amount']
		else
			puts "API error: coinbase data missing"
		end
	else
		puts "Error: Uknown ae_coin: #{coin}"
	end
	return 0
end

# Read config
if (ARGV.length >= 1)
    apiKey = ARGV[0]

    # Optional settings
    options = {}
    options[:ignored_coins] = []
    options[:individual] = false
    options[:coin_precision] = 8
    options[:fiat_precision] = 2
	options[:ae_coin] = "bitcoin"
    options[:showTime] = false

    # Read options if avaialable
    for i in (1...ARGV.length)
        arg = ARGV[i]
        
        if (arg.start_with? "-coin_precision=")
            options[:coin_precision] = arg.sub("-coin_precision=", "")
        elsif (arg.start_with? "-fiat_precision=")
            options[:fiat_precision] = arg.sub("-fiat_precision=", "")
        elsif (arg == "-individual")    
            options[:individual] = true
        elsif (arg.start_with? "-ignore=")
            options[:ignored_coins] << arg.sub("-ignore=", "").downcase()
		elsif (arg.start_with? "-ae_coin=")
			options[:ae_coin] = arg.sub("-ae_coin=", "").downcase()
		elsif (arg == "-time")    
            options[:showTime] = true
        else
            puts "Unknown option: #{arg}"
        end
    end
    
    # Get data from MPH
    balance = Balance.createFromMPH(apiKey)
    if (balance != nil)
		# Get exchange rates
		balance.updateExchangeRates()
	
		# Find ae_coin
		aeCoin = balance.coins[options[:ae_coin]]
		if (aeCoin == nil)
			puts "Enable to find ae_coin: #{options[:ae_coin]}.  Using bitcoin."
			aeCoin = balance.coins['bitcoin']
		end
	
		# Print time
		if (options[:showTime])
			time = Time.now.localtime
			puts "Balance at #{time.to_i} (#{time.strftime("%H:%M:%S")}):"
		end
	
        # Print individual values
        if (options[:individual])
            balance.coins.values.each {|coin|
                # Check if coin is ignored
                if (!options[:ignored_coins].include? coin.name)
					printf("%0.#{options[:coin_precision]}f %s == %0.#{options[:coin_precision]}f %s\n", coin.total(), coin.name, coin.totalValueIn(aeCoin), options[:ae_coin])
                else
					printf("%0.#{options[:coin_precision]}f %s ignored.\n", coin.total(), coin.name)
                end
            }
        end
        
        # Sum total values
        total = balance.coins.values.inject(0){|sum, coin|
			# Make sure coin is included
			if (!options[:ignored_coins].include? coin.name)
				sum + coin.totalValueIn(aeCoin)
			else
				sum
			end
        }
		
        # Print total value
		printf("Total %s: %0.#{options[:coin_precision]}f\n", options[:ae_coin], total)
		
		# Get ae -> USD rate from coinbase
		coinbaseRate = getCoinbaseRate(options[:ae_coin])
		if (coinbaseRate != 0)
            printf("Total USD: %0.#{options[:fiat_precision]}f\n", total.to_f * coinbaseRate.to_f)
		else
			puts "Error getting exchange value, check your ae_coin."
		end
    else
        puts "Error getting balance information from MPH, check your API key and internet connection."
    end
else
    puts "Usage: ruby total_balance.rb <API_key> [options]"
    puts "Options:"
    puts "  -ignore=<COIN>            - Don't count a specified coin"
    puts "  -ae_coin=<COIN>           - Set auto exchange coin (default bitcoin)"
    puts "  -individual               - Print value of each coin"
    puts "  -coin_precision=<DIGITS>  - Number of digits to display for coin values (default 8)"
    puts "  -fiat_precision=<DIGITS>  - Number of digits to display for fiat values (default 2)"
end
