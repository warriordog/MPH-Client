require 'miner/event/events'

# Actions module
module Actions
    # Module logger
    @@logger = nil

    # ID -> instance maps
    @@actions = {}
    
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
            
            Actions.logger.debug "Empty action '#{actionId}' called from '#{worker.id}'"
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
                # Log action
                when "log"
                    return ActionLog.new(id, action, args)
                # Exec action
                when "exec_app"
                    return ActionRun.new(id, action, args)              
                # Exec any action
                when "exec_any"
                    return ActionExec.new(id, action, args)             
                # Pause mining
                when "pause_mining"
                    return ActionPause.new(id, action, args)
                # Resume mining
                when "resume_mining"
                    return ActionResume.new(id, action, args)
                # Log a custom action
                when "log_custom"
                    return ActionLogCustom.new(id, action, args)
                # Crash the worker
                when "debug_crash"
                    return ActionCrash.new(id, action, args)
                else
                    Actions.logger.warn {"Unkown action id '#{action}' for action '#{id}'.  It will not be created."}
                    
                end
            else
                Actions.logger.error {"Missing action ID for action '#{json[:id]}'.  It will not be created."}
            end
            
            return nil
        end
    end

    # Action for logging a string
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
                    @logFunc = lambda {|worker, vars|
                    
                        # Fill in variables
                        currentMessage = Args.injectArgs(message, vars, worker.logger) {|key, value|
                            # Print out nil correctly
                            if (value == nil)
                                "nil"
                            # Print out floats in a reasonable way
                            elsif (value.is_a? Float)
                                "%0.8f" % [value]
                            # Print out normally
                            else
                                value.to_s
                            end
                        }

                        # Finally print message 
                        worker.logger.log(severity, currentMessage)
                    }
                else
                    # empty lambda
                    @logFunc = lambda {}
                    Actions.logger.warn "Invalid logger severity: #{args[:severity]}"
                end
            else
                # empty lambda
                @logFunc = lambda {}
                Actions.logger.warn "Event action '#{actionId}' in action '#{id}' is missing required argument(s) 'severity', 'message' and will be disabled."
            end
        end
        
        # Override
        def execute(worker, vars)
            @logFunc.call(worker, vars)
        end
    end

    # Action for running a registered program
    class ActionRun < Action
        def initialize(id, actionId, args)
            super(id, actionId, args)
            
            if (args.include? :id)
                # Get the matching app
                @app = Application.getApp(args[:id])
                if (@app != nil)
                
                    # Args from config are symbolized but we need un-symbolized args for app
                    @appArgs = {}
                    if (args.include? :context)
                        args[:context].each {|key, value| @appArgs[key.to_s] = value}
                    end
                else
                    Actions.logger.warn "Unkown app '#{args[:id]}' in action '#{id}'"
                end
            else
                Actions.logger.warn "Event action '#{actionId}' in action '#{id}' is missing required argument(s) 'id' and will be disabled."
                @app = nil
            end
        end
        
        # Override
        def execute(worker, vars)
            exec = Application::Executor.new(@app)
            exec.start(@appArgs)
        end
    end
    
    # Action for directly running an unregistered program
    class ActionExec < Action
        def initialize(id, actionId, args)
            super(id, actionId, args)
            
            # Get command name
            if (args.include? :command)
                # Set synchronized (or default to not)
                if (args.include? :synchronized)
                    @synchronized = args[:synchronized]
                else
                    @synchronized = false
                end
                    
                # Create app
                @app = Application::App.createFromJSON("action/#{id}", args[:command])
                
                # Make sure it was created
                if (@app == nil)
                    Actions.logger.warn "Unable to create command in '#{actionId}'.  Action will be disabled."
                end
            else
                Actions.logger.warn "Event action '#{actionId}' in action '#{id}' is missing required argument(s) 'cmd' and will be disabled."
            end
        end
        
        # Override
        def execute(worker, vars)
            if (@app != nil)
                exec = Application::Executor.new(@app)
                exec.start(worker.getAppEnvironment())
                
                # Wait for finish
                if (@synchronized)
                    exec.waitForTerminate()
                end
            end
        end
    end
    
    # Action for pausing mining
    class ActionPause < Action
        def initialize(id, actionId, args)
            super(id, actionId, args)
        end
        
        def execute(worker, vars)
            worker.pauseMining()
        end
    end
    
    # Action for resuming mining
    class ActionResume < Action
        def initialize(id, actionId, args)
            super(id, actionId, args)
        end
        
        def execute(worker, vars)
            worker.resumeMining()
        end
    end
    
    # Action for logging a string with a custom logger
    class ActionLogCustom < Action
        def initialize(id, actionId, args)
            super(id, actionId, args)
            
            # Make sure args are valid
            if (args.include?(:name) && args.include?(:message))
                # create logger
                toF = ((!args.include? :toFile) || (args[:toFile]))
                toC = ((!args.include? :toConsole) || (args[:toConsole]))
                logger = Log.createLogger(args[:name], toFile: toF, toConsole: toC)
            
                # logger severity (converted to upper case)
                if (args.include? :severity)
                    severity = Logger::Severity.const_get(args[:severity].upcase)
                else
                    severity = Logger::INFO
                end
                
                # Make sure severity was valid
                if (severity != nil)
                
                    # logger message
                    message = args[:message]
                    
                    # setup lambda to log
                    @logFunc = lambda {|worker, vars|
                    
                        # Fill in variables
                        currentMessage = Args.injectArgs(message, vars, logger) {|key, value|
                            # Print out nil correctly
                            if (value == nil)
                                "nil"
                            # Print out floats in a reasonable way
                            elsif (value.is_a? Float)
                                "%0.8f" % [value]
                            # Print out normally
                            else
                                value.to_s
                            end
                        }

                        # Finally print message 
                        logger.log(severity, currentMessage)
                    }
                else
                    # empty lambda
                    @logFunc = lambda {}
                    Actions.logger.warn "Invalid logger severity: #{args[:severity]}"
                end
            else
                # empty lambda
                @logFunc = lambda {}
                Actions.logger.warn "Event action '#{actionId}' in action '#{id}' is missing required argument(s) 'name', 'message' and will be disabled."
            end
        end
        
        # Override
        def execute(worker, vars)
            @logFunc.call(worker, vars)
        end
    end
    
    # Debug action to crash a worker
    class ActionCrash < Action
        def initialize(id, actionId, args)
            super(id, actionId, args)
            
            if (args.include? :message)
                @message = args[:message]
            else
                @message = nil
            end
        end
        
        def execute(worker, vars)
            Actions.logger.warn "Debug crash activated for #{worker.id}"
            
            # Ka boom
            raise @message
        end
    end
    
    # Gets the events logger
    def self.logger()
        if (@@logger == nil)
            @@logger = Log.createLogger("Event/Actions")
        end
        return @@logger
    end
    
    # Gets an action instance by ID
    def self.getAction(id)
        return @@actions[id.to_sym]
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
end