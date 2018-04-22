#--------------------
# Config file loader
#--------------------

require 'json'

require 'util/log'

CFG_VERSION_DEFAULT = 5
CFG_VERSION_MAIN = 6
CFG_VERSION_ALGORITHMS = 5
CFG_VERSION_MINERS = 6
CFG_VERSION_WORKERS = 6

module Config
    # Module logger
    @@logger = Log.createLogger("Config")
    
    # Settings hash
    @@settings = nil
    
    # Algorithms hash
    @@algorithms = nil
    
    # Miners hash
    @@miners = nil
    
    # Workers hash
    @@workers = nil

    def self.loadConfig(cfgfile)
        # Read main file
        json = self.loadJson(cfgfile, CFG_VERSION_MAIN);
        
        # Make sure it loaded
        if (json != nil)
            @@settings = json[:settings]
            @@algorithms = self.loadJson(json[:algorithms], CFG_VERSION_ALGORITHMS)[:algorithms]
            @@miners = self.loadJson(json[:miners], CFG_VERSION_MINERS)[:miners]
            
            @@workers = {}
            json[:workers].each { |workerFile|
                self.loadJson(workerFile, CFG_VERSION_WORKERS)[:workers].each { |id, worker|
                    @@workers[id.to_s] = worker
                }
            }
            if (@@workers.empty?)
                @@logger.warn "No workers loaded, please check your config"
            end
        end
        
        # Make sure it loaded
        return @@settings != nil && @@algorithms != nil && @@miners != nil && @@workers != nil
    end
    
    def self.loadJson(path, expectedVersion = CFG_VERSION_DEFAULT)
        # Read file as string of json
        file = IO.read(path)
        if (file != nil)
            # rescue JSON parse errors
            begin
                # Parse json to hash
                json = JSON.parse(file, :symbolize_names => true)
                
                # Make sure its valid
                if (json != nil)
                    # check version
                    if (json[:config_version] == expectedVersion)
                        
                        # It's good!
                        return json
                    else
                        @@logger.fatal("Outdated config file '#{path}', please update it.")
                    end
                else
                    @@logger.fatal("Malformed config file '#{path}', check your JSON.")
                end
            rescue JSON::ParserError => ex
                @@logger.fatal("JSON errors in '#{path}'.")
                
                # Print specific JSON error
                if (ex != nil)
                    @@logger.fatal ex.message.gsub(/[\r\n]/, "\\n");
                end
            end
        else
            @@logger.fatal("Unable to access config file '#{path}'.")
        end
        
        # Return nil on error
        return nil
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
