#--------------------
# Config file loader
#--------------------

require 'json'

module Config
    # Config file instance
    @@cfg = nil
    
    # Settings hash
    @@settings = nil
    
    # Algorithms hash
    @@algorithms = nil
    
    # Miners hash
    @@miners = nil
    
    # Workers hash
    @@workers = nil

    def self.loadConfig(cfgfile)
        # Read as json string
        file = IO.read(cfgfile)
        if (file != nil)
            # Convert to hash
            json = JSON.parse(file, :symbolize_names => true)
            if (json != nil)
                # check version
                if (json[:config_version] == 3)
                    # save config
                    @@cfg = json
                    @@settings = json[:settings]
                    @@algorithms = json[:algorithms]
                    @@miners = json[:miners]
                    @@workers = json[:workers]
                else 
                    # TODO upgrade config
                    puts "Outdated config file, please update to continue."
                end
            else
                puts "Malformed config file, check your JSON."
            end
        else
            puts "Unable to access config file '#{cfgfile}.'"
        end
    end
    
    def self.cfg()
        return @@cfg
    end
    
    def self.settings()
        return @@settings
    end
    
    def self.algorithms()
        return @@algorithms
    end
    
    def self.miners()
        return @@miners
    end
    
    def self.workers()
        return @@workers
    end
end
