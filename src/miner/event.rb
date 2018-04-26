#-------------------
# Worker event code
#-------------------

# Events module
module Events
    # Module logger
    @@logger = Log.createLogger("Events", toFile: true, toConsole: true)

	# ID -> instance maps
	@@triggers = {}
	@@actions = {}
	
	# ------------------
	# | Action classes |
	# ------------------
	
	# An action that can be taken
	class Action
		def initialize(id, actionId, args)
			@id = id
			@actionId = actionId
			@args = args
		end
		
		attr_reader :id, :actionId, :args
		
		def execute(worker, vars)
			# Do nothing
			
			Events.logger.debug "Empty action '#{actionId}' called from '#{worker.id}'"
		end
		
		def self.createFromJSON(id, json)
			if (json.include? :action_id)
				# Action id
				action = json[:action_id].downcase
				
				# Action args
				if (json.include? :args)
					args = json[:args]
				else
					# Some actions may have optional args
					args = {}
				end
				
				# Create appropriate subclass
				case action
				when "log"
					# Log action
					return ActionLog.new(id, action, args)
				else
					Events.logger.warn {"Unkown action id '#{action}' for action '#{id}'.  It will not be created."}
					
				end
			else
				Events.logger.error {"Missing action ID for action '#{json[:id]}'.  It will not be created."}
			end
			
			return nil
		end
	end

	# Action for 
	class ActionLog < Action
		def initialize(id, actionId, args)
			super(id, actionId, args)
			
			# Make sure args are valid
			if (args.include?(:severity) && args.include?(:message))
			
				# logger severity (converted to upper case)
				severity = Logger::Severity.const_get(args[:severity].upcase)
				if (severity != nil)
				
					# logger message
					message = args[:message]
					
					# setup lambda to log
					@logFunc = lambda {|worker, vars| worker.logger.log(severity, message)}
				else
					# empty lambda
					@logFunc = lambda {}
					Events.logger.warn "Invalid logger severity: #{args[:severity]}"
				end
			else
				# empty lambda
				@logFunc = lambda {}
				Events.logger.warn "Event action '#{actionId}' is missing required argument(s) 'severity', 'message' and will be disabled."
			end
		end
		
		# Override
		def execute(worker, vars)
			@logFunc.call(worker, vars)
		end
	end

	# -------------------
	# | Trigger classes |
	# -------------------
	
	# An event trigger
	class Trigger
		def initialize(id, triggerId, filters)
			@id = id
			@triggerId = triggerId
			@filters = filters
		end
		
		attr_reader :id, :triggerId, :filters
		
		def self.createFromJSON(id, json)
			if (json.include? :trigger_id)
				triggerId = json[:trigger_id].downcase
			
				case triggerId
				when "startup"
					return StartupTrigger.new(id, triggerId, json[:filters])
				when "shutdown"
					return ShutdownTrigger.new(id, triggerId, json[:filters])
				when "switch_coin"
					return CoinSwitchTrigger.new(id, triggerId, json[:filters])
				when "start_mining"
					return StartMiningTrigger.new(id, triggerId, json[:filters])
				when "stop_mining"
					return StopMiningTrigger.new(id, triggerId, json[:filters])
				else
					Events.logger.warn "Unkown trigger id '#{triggerId}' for trigger '#{id}'.  It will not be created."
				end
			else
				Events.logger.warn "No trigger id for trigger '#{id}'.  It will not be created."
			end
			
			return nil
		end
	end

	# Mid-class for triggers activated by worker signals
	class WorkerTrigger < Trigger
		def initialize(id, triggerId, filters, signal)
			super(id, triggerId, filters)
			
			# The signal to expect
			@signal = signal
		end
		
		# Add this trigger to a worker
		def addToWorker(worker, event)
			worker.addListener(@signal, self) { |wkr, vars|
				prepareVars(wkr, vars)
				event.fire(worker, vars)
			}
		end
		
		# Remove this trigger from a worker
		def removeFromWorker(worker)
			worker.removeListener(self)
		end
		
		# Override in subclasses to tweak vars before passing on
		def prepareVars(worker, vars)
		end
	end
	
	# Trigger that activates when worker starts
	class StartupTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :startup)
		end
		
		# Override
		def prepareVars(worker, vars)
			Events.logger.debug {"Activating startup trigger on '#{worker.id}'"}
		end
	end

	# Trigger that activates when worker stops
	class ShutdownTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :shutdown)
		end
		
		# Override
		def prepareVars(worker, vars)
			Events.logger.debug {"Activating shutdown trigger on '#{worker.id}'"}
		end
	end

	# Trigger that activates when worker switches coins
	class CoinSwitchTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :switch_coin)
		end
		
		# Override
		def prepareVars(worker, vars)
			Events.logger.debug {"Activating coin switch trigger on '#{worker.id}'"}
		end
	end
	
	# Trigger that activates when worker starts mining
	class StartMiningTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :start_mining)
		end
		
		# Override
		def prepareVars(worker, vars)
			Events.logger.debug {"Activating start mining trigger on '#{worker.id}'"}
		end
	end
	
	# Trigger that activates when worker stops mining
	class StopMiningTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :stop_mining)
		end
		
		# Override
		def prepareVars(worker, vars)
			Events.logger.debug {"Activating stop mining trigger on '#{worker.id}'"}
		end
	end
	
	# --------------
	# | Event Code |
	# --------------
	
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
				trigger = Events.getTrigger(json[:trigger])
				if (trigger != nil)
					
					# Lookup action
					if (json.include? :action)
						action = Events.getAction(json[:action])
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
	
	# Gets a trigger instance by ID
	def self.getTrigger(id)
		return @@triggers[id.to_sym]
	end
	
	# Gets an action instance by ID
	def self.getAction(id)
		return @@actions[id.to_sym]
	end
	
	# Gets the events logger
    def self.logger()
        return @@logger
    end
	
	def self.loadTrigger(id, json)
		trigger = Trigger.createFromJSON(id, json)
		if (trigger != nil)
			@@triggers[id] = trigger
		end
	end
	
	def self.loadTriggers()
		Config.triggers.each {|id, json| self.loadTrigger(id, json)}
	end
	
	def self.loadAction(id, json)
		action = Action.createFromJSON(id, json)
		if (action != nil)
			@@actions[id] = action
		end
	end
	
	def self.loadActions()
		Config.actions.each {|id, json| self.loadAction(id, json)}
	end
	
	def self.loadActionsAndEvents()
		self.loadTriggers()
		self.loadActions()
	end
end