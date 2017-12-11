#--------------------
# Config file loader
#--------------------

#require 'pp'

# TODO use symbols instead of strings for performance
def loadConfig(cfgfile)
    # Read as json string
    file = IO.read(cfgfile)
    if (file != nil)
        # Convert to hash
        json = JSON.parse(file)
        if (json != nil)
            # debug print json
            #pp json
            # check version
            if (json['config_version'] == 0)
                # TODO return a class instead
                return json
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
    
    return nil;
end
