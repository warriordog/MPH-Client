#-------------------
# Worker event code
#-------------------

# An action that can be taken
class Action
	def initialize(actionId, args)
		@actionId = actionId
		@args = args
	end
	
	attr_reader :actionId, :args
	
	def execute(worker)
		# Do nothing
		
		@worker.logger.debug "Empty action '#{actionId}' called from '#{worker.id}'"
	end
	
	def self.createFromJSON(json)
		if (json.include? :id)
			# Action id
			action = json[:id].downcase
			
			if (json.include? :args)
				args = json[:args]
			else
				# Some actions may have optional args
				args = {}
			end
			
			case action
			when "log"
				# Log action
				return ActionLog.new(action, args)
			else
				Wkr.logger.warn {"Unkown action id '#{action}'"}
				
				# Return empty action
				return Action.new(action, args)
				
			end
		else
			Wkr.logger.error {"Missing action ID for action '#{json[:id]}'"}
		end
		
		# Return empty action
		return Action.new(nil, {})
	end
end

# Action for 
class ActionLog < Action
	def initialize(actionId, args)
		super(actionId, args)
		
		if (args.include?(:severity) && args.include?(:message))
			# logger severity (converted to upper case)
			severity = Logger::Severity.const_get(args[:severity].upcase)
			if (severity != nil)
				# logger message
				message = args[:message]
				
				# setup lambda to log
				@logFunc = lambda {|worker| worker.logger.log(severity, message)}
			else
				# empty lambda
				@logFunc = lambda {}
				Wkr.logger.warn "Invalid logger severity: #{args[:severity]}"
			end
		else
			# empty lambda
			@logFunc = lambda {}
			Wkr.logger.warn "Event action '#{actionId}' is missing required argument(s) 'severity', 'message' and will be disabled."
		end
	end
	
	# Override
	def execute(worker)
		@logFunc.call worker
	end
end

# An event trigger
class Trigger
	def initialize(event, triggerId)
		@triggerId = triggerId
		@event = event
	end
	
	attr_reader :triggerId, :event

	# Adds hooks/listeners/etc to worker
	#   Event is event that this listner is linked to
	def addToWorker(worker)
		worker.logger.debug {"Not registering unknown trigger '#{@triggerId}' for '#{worker.id}'."}
	end
	
	# Removes hooks/listeners/etc and shuts down
	def removeFromWorker(worker)
		worker.logger.debug {"Not deregistering unknown trigger '#{@triggerId}' for '#{worker.id}'."}
	end
	
	def self.createFromID(event, triggerId)
		triggerId = triggerId.downcase
	
		case triggerId
		when "startup"
			return StartupTrigger.new(event, triggerId)
		when "shutdown"
			return ShutdownTrigger.new(event, triggerId)
		else
			Wkr.logger.warn "Unkown trigger id '#{triggerId}'."
			return Trigger.new(event, triggerId)
		end
	end
end

# Trigger that activates when worker starts
class StartupTrigger < Trigger
	def initialize(event, triggerId)
		super(event, triggerId)
	end
	
	# Override
	def addToWorker(worker)
		worker.addListener(:startup, self) { |wkr|
			worker.logger.debug {"Activating startup trigger on '#{worker.id}'"}
			@event.trigger()
		}
	end
	
	# Override
	def removeFromWorker(worker)
		worker.removeListener(self)
	end
end

# Trigger that activates when worker stops
class ShutdownTrigger < Trigger
	def initialize(event, triggerId)
		super(event, triggerId)
	end
	
	# Override
	def addToWorker(worker)
		worker.addListener(:shutdown, self) { |wkr|
			worker.logger.debug {"Activating shutdown trigger on '#{worker.id}'"}
			@event.trigger()
		}
	end
	
	# Override
	def removeFromWorker(worker)
		worker.removeListener(self)
	end
end

# Parent event class
class Event
	def initialize()
		@trigger = nil
		@actions = []
		@workers = []
	end
	
	attr_reader :workers, :actions
	attr_accessor :trigger
	
	# Activates the actions in this event
	def trigger()
		@workers.each {|worker|
			@actions.each {|action| 
				action.execute worker
			}
		}
	end
	
	# Activates triggers
	def addToWorker(worker)
		@workers << worker
		@trigger.addToWorker(worker)
	end
	
	# Deactivates triggers
	def removeFromWorker(worker)
		@workers.remove worker
		@trigger.removeFromWorker(worker)
	end
	
	def self.createFromJSON(json)
		# Create event
		event = Event.new()
		
		# Add actions
		if ((json.include? :actions) && (!json[:actions].empty?))
			json[:actions].each { |actionJson|
				event.actions << Action.createFromJSON(actionJson)
			}
		else
			Wkr.logger.warn {"No actions for event '#{json}'"}
		end
		
		# Create trigger
		if (json.include? :trigger)
			event.trigger = Trigger.createFromID(event, json[:trigger])
		else
			Wkr.logger.warn {"No triggers for event in '#{json}'"}
		end
		
		return event
	end
end