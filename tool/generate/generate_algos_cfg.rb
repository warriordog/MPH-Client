
# Generates the "algorithms" config section by listing all supported coins from MPH

require 'json'
require 'net/http'

json = Net::HTTP.get(URI("https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"))
resp = JSON.parse(json)

if (resp['success'])
    stats = resp['return']
    
    algos = Hash.new { |hash, key| hash[key] = {'name' => key, 'coins' => {}} }
    
    stats.each {|statCoin| 
        coin = {'name' => statCoin['coin_name']}
        
        algos[statCoin['algo'].downcase]['coins'][statCoin['coin_name']] = coin
    }
    
    puts JSON.pretty_generate(algos, {:indent => '  '})
else
    puts "Server returned error"
end


