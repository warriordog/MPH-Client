#---------------------------------
# API endpoints for MiningPoolHub
#---------------------------------

require 'json'
require 'net/http'

require 'util/log'

module MPH
    # Module logger
    @@logger = Log.createLogger("MPH_API")

    # Gets the mining and profit statistics for a (or all) coin(s)
    def self.getMiningAndProfitsStatistics(coin = nil)
        begin
            # URL for coin (or all coins)
            url = "https://#{coin != nil ? coin + "." : ""}miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"
            
            # Convert to URI
            uri = URI.parse(url)
            
            # send request
            resp = Net::HTTP.get(uri)
            
            # Check for network errors
            if (resp != nil)
                # Parse json
                json = JSON.parse(resp, :symbolize_names => true)
                
                # Check for success
                if (json[:success] == true)
                    # if "return" is missing, then this will just return nil, which is the error status anyway
                    return json[:return]
                else
                    # Return nil if server had error
                    @@logger.warn("Server error in getminingandprofitsstatistics: '#{resp[:return]}'")
                    return nil
                end
            else
                @@logger.error("Network error while getting mining statistics.")
            end
        rescue URI::InvalidURIError => e
            @@logger.error("Invalid URI generated for MPH API, was a bad coin entered?  Error was #{e}")
        rescue JSON::JSONError => e
            @@logger.error("Invalid JSON returned from MPH: #{e}")
        rescue Exception => e
            @@logger.error("Error in getminingandprofitsstatistics: #{e}")
        end
        
        # Return nil in case of errors
        return nil
    end
	
	# converts an MPH rate into H/s
	def self.parseRate(rateString)
		if (rateString.empty?)
			return nil
		else
			unit = rateString[-1]
			value = rateString[0...-1]
			
			case unit
			when 'H'
				return value.to_i
			when 'K'
				return value.to_i * 1000
			when 'M'
				return value.to_i * 1000 * 1000
			when 'G'
				return value.to_i * 1000 * 1000 * 1000
			when 'T'
				return value.to_i * 1000 * 1000 * 1000 * 1000
			else
				return rateString.to_i
			end
		end
	end
	
	# Same as parseRate, but converts to float Mh/s
	def self.parseRateMh(rateString)
		if (rateString.empty?)
			return nil
		else
			unit = rateString[-1]
			value = rateString[0...-1]
			
			case unit
			when 'H'
				return value.to_f / 1000000.0
			when 'K'
				return value.to_f / 1000.0
			when 'M'
				return value.to_f
			when 'G'
				return value.to_f * 1000.0
			when 'T'
				return value.to_f * 1000.0 * 1000.0
			else
				# assume H/s
				return rateString.to_f  / 1000000.0
			end
		end
	end
end
