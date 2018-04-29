#-------------------
# Worker event code
#-------------------

require 'util/args'
require 'util/log'
require 'miner/coins'
require 'miner/miners' 

# Events module
module Events
    # Module logger
    @@logger = Log.createLogger("Events", toFile: true, toConsole: true)
	
	# Event class
	class Event
		def initialize(trigger, action)
			@trigger = trigger
			@action = action
		end
		
		attr_reader :action, :trigger
		
		# Activates the actions in this event
		def fire(worker, vars)
			action.execute(worker, vars)
		end
		
		def self.createFromJSON(json)
			
			# Lookup trigger
			if (json.include? :trigger)
				trigger = Triggers.getTrigger(json[:trigger])
				if (trigger != nil)
					
					# Lookup action
					if (json.include? :action)
						action = Actions.getAction(json[:action])
						if (action != nil)
					
							# Create event
							return Event.new(trigger, action)
						else
							Events.logger.error "Unkown action '#{json[:action]}' in event '#{json}'"
						end
					else
						Events.logger.error "No action for event '#{json}'."
					end
				else
					Events.logger.error "Unkown trigger '#{json[:trigger]}' in event '#{json}'"
				end
			else
				Events.logger.error "No trigger for event in '#{json}', it will not be added."
			end
			
			# Don't try to create invalid events
			return nil
		end
	end
	
	# Gets the events logger
    def self.logger()
        return @@logger
    end
end