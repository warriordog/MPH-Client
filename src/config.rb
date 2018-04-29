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
    @@logger = nil
    
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
            @@algorithms = self.loadJsons(json[:algorithms], :algorithms, CFG_VERSION_ALGORITHMS)
            @@miners = self.loadJsons(json[:miners], :miners, CFG_VERSION_MINERS)
            @@triggers = self.loadJsons(json[:triggers], :triggers, CFG_VERSION_TRIGGERS)
            @@actions = self.loadJsons(json[:actions], :actions, CFG_VERSION_ACTIONS)
            @@applications = self.loadJsons(json[:applications], :applications, CFG_VERSION_APPLICATIONS)
            @@workers = self.loadJsons(json[:workers], :workers, CFG_VERSION_WORKERS)
        end
        
        # Make sure it loaded
        return !@@settings.empty? && !@@algorithms.empty? && !@@miners.empty? && !@@workers.empty? && !@@triggers.empty? && !@@actions.empty? && !@@applications.empty? && !@@workers.empty?
    end
    
    def self.loadJsons(paths, sharedField, expectedVersion = CFG_VERSION_DEFAULT)
            hash = {}
            paths.each {|path|
                json = self.loadJson(path, expectedVersion)
                json[sharedField].each { |id, entry|
                    hash[id] = entry
                }
            }
            return hash
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
                        Config.logger.fatal("Outdated config file '#{path}', please update it.")
                    end
                else
                    Config.logger.fatal("Malformed config file '#{path}', check your JSON.")
                end
            rescue JSON::ParserError => ex
                Config.logger.fatal("JSON errors in '#{path}'.")
                
                # Print specific JSON error
                if (ex != nil)
                    Config.logger.fatal ex.message.gsub(/[\r\n]/, "\\n");
                end
            end
        else
            Config.logger.fatal("Unable to access config file '#{path}'.")
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
    
    def self.logger()
        if (@@logger == nil)
            @@logger = Log.createLogger("Log")
        end
        return @@logger
    end
end
