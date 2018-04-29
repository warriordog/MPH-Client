require 'miner/event/events' 

# Triggers module
module Triggers
    # Module logger
    @@logger = Log.createLogger("Triggers", toFile: true, toConsole: true)

    # ID -> instance maps
    @@triggers = {}
    
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
				when "switch_algorithm"
					return AlgoSwitchTrigger.new(id, triggerId, json[:filters])
				when "timer"
					return TimerTrigger.new(id, triggerId, json[:filters])
				when "timeout"
					return TimeoutTrigger.new(id, triggerId, json[:filters])
				else
					Triggers.logger.warn "Unkown trigger id '#{triggerId}' for trigger '#{id}'.  It will not be created."
				end
			else
				Triggers.logger.warn "No trigger id for trigger '#{id}'.  It will not be created."
			end
			
			return nil
		end
		
		# Add this trigger to a worker
		def addToWorker(worker, event)
		end
		
		# Remove this trigger from a worker
		def removeFromWorker(worker)
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
			Triggers.logger.debug {"Activating startup trigger on '#{worker.id}'"}
		end
	end

	# Trigger that activates when worker stops
	class ShutdownTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :shutdown)
		end
		
		# Override
		def prepareVars(worker, vars)
			Triggers.logger.debug {"Activating shutdown trigger on '#{worker.id}'"}
		end
	end

	# Trigger that activates when worker switches coins
	class CoinSwitchTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :switch_coin)
		end
		
		# Override
		def prepareVars(worker, vars)
			Triggers.logger.debug {"Activating coin switch trigger on '#{worker.id}'"}
		end
	end
	
	# Trigger that activates when worker starts mining
	class StartMiningTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :start_mining)
		end
		
		# Override
		def prepareVars(worker, vars)
			Triggers.logger.debug {"Activating start mining trigger on '#{worker.id}'"}
		end
	end
	
	# Trigger that activates when worker stops mining
	class StopMiningTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :stop_mining)
		end
		
		# Override
		def prepareVars(worker, vars)
			Triggers.logger.debug {"Activating stop mining trigger on '#{worker.id}'"}
		end
	end
	
	# Trigger that activates when worker switches algorithm
	class AlgoSwitchTrigger < WorkerTrigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters, :switch_algo)
		end
		
		# Override
		def prepareVars(worker, vars)
			Triggers.logger.debug {"Activating algo switch trigger on '#{worker.id}'"}
		end
	end
	
	# Trigger that activates on a timer
	class TimerTrigger < Trigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters)
			
			# Get interval
			if (filters.include? :interval)
				@interval = Float(filters[:interval])
				if (@interval == nil)
					Triggers.logger.warn "Invalid timer interval: #{filters[:interval]}"
				end
			else
				@interval = nil
				Triggers.logger.warn "Timer triggers require an interval"
			end
		end
		
		# Add this trigger to a worker
		def addToWorker(worker, event)
			if (@interval != nil)
				Triggers.logger.debug {"Attching worker '#{worker.id}' to timer '#{id}'"}
				
				# Wait for start event
				worker.addListener(:startup, self) {
					Triggers.logger.debug {"Timer '#{@id}' activated."}
				
					# Create timer thread
					Thread.new {
						while (true)
							begin
								# Wait for interval
								sleep @interval
								
								# Create variable data
								vars = {'TIMER.ID' => @id}
								worker.injectGlobalVars(vars)
								
								# fire event
								event.fire(worker, vars)
							rescue Exception => e
								Triggers.logger.error "Exception in timer thread"
								Triggers.logger.error e
								Triggers.logger.error e.backtrace.join("\n\t")
							end
						end
					}
				}
			else
			
			end
		end
		
		# Remove this trigger from a worker
		def removeFromWorker(worker)
			Triggers.logger.debug {"Removing worker '#{worker.id}' from timer '#{id}'"}
			worker.removeListener(self)
		end
	end
	
	# Trigger that activates on a timeout
	class TimeoutTrigger < Trigger
		def initialize(id, triggerId, filters)
			super(id, triggerId, filters)
			
			# Get delay
			if (filters.include? :delay)
				@delay = Float(filters[:delay])
				if (@delay == nil)
					Triggers.logger.warn "Invalid timer delay: #{filters[:delay]}"
				end
			else
				@delay = nil
				Triggers.logger.warn "Timer triggers require an delay"
			end
		end
		
		# Add this trigger to a worker
		def addToWorker(worker, event)
			if (@delay != nil)
				Triggers.logger.debug {"Attching worker '#{worker.id}' to timeout '#{id}'"}
				
				# Wait for start event
				worker.addListener(:startup, self) {
					Triggers.logger.debug {"Timeout '#{@id}' activated."}
				
					# Create timeout thread
					Thread.new {
						begin
							# Wait for delay
							sleep @delay
							
							# Create variable data
							vars = {'TIMEOUT.ID' => @id}
							worker.injectGlobalVars(vars)
							
							# fire event
							event.fire(worker, vars)
						rescue Exception => e
							Triggers.logger.error "Exception in timeout thread"
							Triggers.logger.error e
							Triggers.logger.error e.backtrace.join("\n\t")
						end
					}
				}
			else
			
			end
		end
		
		# Remove this trigger from a worker
		def removeFromWorker(worker)
			Triggers.logger.debug {"Removing worker '#{worker.id}' from timeout '#{id}'"}
			worker.removeListener(self)
		end
	end
	
	# Gets the events logger
    def self.logger()
        return @@logger
    end
	
	# Gets a trigger instance by ID
	def self.getTrigger(id)
		return @@triggers[id.to_sym]
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
end