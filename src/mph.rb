#---------------------------------
# API endpoints for MiningPoolHub
#---------------------------------

require 'pp'

module MPH

    # Gets the mining and profit statistics for a (or all) coin(s)
    def self.getMiningAndProfitsStatistics(coin = nil)
        begin
            # URL for coin (or all coins)
            url = "https://#{coin != nil ? coin + "." : ""}miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"
            
            # Convert to URI
            uri = URI(url)
            
            # send request
            json = Net::HTTP.get(uri)
            
            # Parse json
            resp = JSON.parse(json)
            
            # Check for success
            if (resp['success'] == true)
                # if "return" is missing, then this will just return nil, which is the error status anyway
                return resp['return']
            else
                # Return nil if server had error
                puts "Server error in getminingandprofitsstatistics: '#{resp['return']}'"
                return nil
            end
        # TODO proper error checking
        # Return nil in case of errors
        rescue Object => o
            puts "Error in getminingandprofitsstatistics: "
            pp o
            return nil
        rescue
            puts "Unknown error in getminingandprofitsstatistics."
            return nil
        end
    end
end
