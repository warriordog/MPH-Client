#--------------------
# Config file loader
#--------------------

require 'json'

require 'util/log'

CFG_VERSION_DEFAULT = 5
CFG_VERSION_MAIN = 7
CFG_VERSION_ALGORITHMS = 5
CFG_VERSION_MINERS = 6
CFG_VERSION_WORKERS = 8
CFG_VERSION_TRIGGERS = 0
CFG_VERSION_ACTIONS = 0
CFG_VERSION_APPLICATIONS = 0

module Config
    #Config module logger
    @@logger = Log.createLogger("Config")
    
    # Settings json data
    @@settings = nil
    
    # Algorithms json data
    @@algorithms = nil
    
    # Miners json data
    @@miners = nil
    
    # Workers json data
    @@workers = nil
    
    # Triggers json data
    @@triggers = nil
    
    # Actions json data
    @@actions = nil
    
    # Applications json data
    @@applications = nil

    def self.loadConfig(cfgfile)
        # Read main file
        json = self.loadJson(cfgfile, CFG_VERSION_MAIN);
        
        # Make sure it loaded
        if (json != nil)
            @@settings = json[:settings]
            @@algorithms = self.loadJson(json[:algorithms], CFG_VERSION_ALGORITHMS)[:algorithms]
            @@miners = self.loadJson(json[:miners], CFG_VERSION_MINERS)[:miners]
            @@triggers = self.loadJson(json[:triggers], CFG_VERSION_TRIGGERS)[:triggers]
            @@actions = self.loadJson(json[:actions], CFG_VERSION_ACTIONS)[:actions]
            @@applications = self.loadJson(json[:applications], CFG_VERSION_APPLICATIONS)[:applications]
            
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
        return @@settings != nil && @@algorithms != nil && @@miners != nil && @@workers != nil && @@triggers != nil && @@actions != nil && @@applications != nil
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
    
    def self.triggers()
        return @@triggers
    end
    
    def self.actions()
        return @@actions
    end
    
    def self.applications()
        return @@applications
    end
end
