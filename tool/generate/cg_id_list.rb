#
# cg_id_list.rb
# Connects to CoinGecko and extracts the current mapping of coin IDs -> names from a page
#

require "net/http"
require "json"

# URL to download from
base_url = "https://www.coingecko.com/en"

# Pattern to look for to start collecting IDs
start_pattern = "<select name=\"coins_to_search\" id=\"coins_to_search\" style=\"width:100%\" class=\"select2-search-coins\">"
# Pattern to stop collecting names
stop_pattern = "</select>"
# Pattern to match ID
match_pattern = /<option value\=\"(\d+)\">(.*)\s\((.*)\)<\/option>/


# list of {symbol, name, id}
coins = []

# Download page
page = Net::HTTP.get(URI(base_url))

# Extract relevant section
list = page[/#{Regexp.escape(start_pattern)}(.*?)#{Regexp.escape(stop_pattern)}/m]

# Find matches
list.scan(match_pattern) {|id, name, symbol|
    
    coin = {}
    coin['symbol'] = symbol.to_s.force_encoding("UTF-8")
    coin['name'] = name.to_s.force_encoding("UTF-8")
    coin['id'] = id.to_i
    
    if (!coin['symbol'].empty?() && !coin['name'].empty?())
        coins << coin
    end
}

# Print mapping
print JSON.pretty_generate(coins)

