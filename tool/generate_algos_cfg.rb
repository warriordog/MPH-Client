
# Generates the "algorithms" config section by listing all supported coins from MPH

require 'json'
require 'net/http'

json = Net::HTTP.get(URI("https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"))
resp = JSON.parse(json)

if (resp["success"])
    stats = resp["return"]
    
    algos = Hash.new { |hash, key| hash[key] = {"id" => key, "name" => key, "coins" => []} }
    
    stats.each {|statCoin| 
        coin = {}
        coin["id"] = statCoin["coin_name"]
        coin["name"] = coin["id"]
        
        algos[statCoin["algo"].downcase]["coins"] << coin
    }
    
    puts algos.values.to_json    
else
    puts "Server returned error"
end


