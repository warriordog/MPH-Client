#---------------------------------
# API endpoints for MiningPoolHub
#---------------------------------

require_relative 'log'

module MPH
    # Module logger
    @@logger = Log.createLogger("MPH_API")

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
            resp = JSON.parse(json, :symbolize_names => true)
            
            # Check for success
            if (resp[:success] == true)
                # if "return" is missing, then this will just return nil, which is the error status anyway
                return resp[:return]
            else
                # Return nil if server had error
                @@logger.warn("Server error in getminingandprofitsstatistics: '#{resp[:return]}'")
                return nil
            end
        # TODO proper error checking
        # Return nil in case of errors
        rescue o
            @@logger.error("Error in getminingandprofitsstatistics: #{o}")
            return nil
        end
    end
end
