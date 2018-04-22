#--------------------
# Config file loader
#--------------------

require 'json'

require 'util/log'

module Config
    # Module logger
    @@logger = Log.createLogger("Config")

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
        # Read main file
        json = self.loadJson(cfgfile);
        
        # Make sure it loaded
        if (json != nil)
            @@cfg = json
            @@settings = json[:settings]
            @@algorithms = self.loadJson(json[:algorithms])[:algorithms]
            @@miners = self.loadJson(json[:miners])[:miners]
            
            @@workers = {}
            json[:workers].each { |workerFile|
                self.loadJson(workerFile)[:workers].each { |id, worker|
                    @@workers[id.to_s] = worker
                }
            }
        end
    end
    
    def self.loadJson(path)
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
                    if (json[:config_version] == 5)
                        
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
        
        # Return nill on error
        return nil
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
