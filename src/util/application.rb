#
# Utility that provides a framework for running sub-processes in a contro
#

require 'util/log'
require 'util/args'

module Application
    # Module logger
    @@logger = nil

    # Application map (id -> App)
    @@applications = {}
    
    # A registered, runnable application
    class App
        def initialize(id, workingDir, executable, args, daemon, killOnExit)
            @id = id
            @workingDir = workingDir
            @executable = executable
            @args = args
            @daemon = daemon
            @killOnExit = killOnExit
            
            @logger = Log.createLogger("App/" + id, toFile: true, toConsole: true)
        end
        
        attr_reader :id, :workingDir, :executable, :logger, :daemon, :killOnExit
        
        def args(context)
            if (context != nil && !context.empty?)
                return Args.injectArgs(@args, context, @logger)
            else
                return @args
            end
        end
        
        def self.createFromJSON(id, json)
            if (json.include? :workingDir)
                if (json.include? :executable)
                    if (json.include? :args)
                        args = json[:args]
                    else
                        args = ""
                    end
                    
                    daemon = true
                    if (json.include? :daemon)
                        daemon = json[:daemon]
                    end
                    
                    koe = false
                    if (json.include? :killOnExit)
                        koe = json[:killOnExit]
                    end
                    
                    return App.new(id, json[:workingDir], json[:executable], args, daemon, koe)
                else
                    Application.logger.warn "Application '#{id}' is missing an executable.  It will not be created."
                end
            else
                Application.logger.warn "Application '#{id}' is missing a working directory.  It will not be created."
            end
            
            return nil
        end
    end
    
    # A class to execute and monitor an App
    class Executor
        def initialize(app)
            @app = app
        
            # ID of running process (nil if dead)
            # Not synchronized, so be careful when accessing
            @pid = nil
            
            # Monitor thread (may or may not have PID data, don't count on it)
            @thread = nil
            
            # Finalizer to make sure process ends (only used if killOnExit is true)
            @finalizer = Proc.new {
                if (self.alive?)
                    @app.logger.info "Killing application for shutdown."
                    self.stop()
                end
            }
            
            # Set daemon and KOE from app defaults
            self.daemon = @app.daemon
            self.killOnExit = @app.killOnExit
        end
        
        attr_reader :app, :pid
        
        def start(context = {})
            # don't start if already running
            if (!started?())
            
                @app.logger.info "Starting #{@app.id}."
           
                # Create subprocess (INSECURE - uses shell, so don't pass any external data in).
                cmd = "#{@app.executable} #{@app.args(context)}"
                @app.logger.debug {"Command: #{cmd}"}

                # Make sure working dir exists
                if (Dir.exist? @app.workingDir)
                    begin
                        # Linux and windows miners behave differently and need different process code.
                        if (Gem.win_platform?)
                            @app.logger.debug {"Using pipes for IO"}
                            
                            # Don't require until now because this doesn't exist on windows
                            require 'open3'
                            
                            # Start the process
                            # This method doesn't work for programs that use TTYs
                            # BUG: if path does not exist then ruby will exit with no error
                            stdin, stdout, thr = Open3.popen2e(cmd, :chdir => @app.workingDir)
                            @pid = thr.pid # pid of the started process.
                            
                            # Close write pipe
                            stdin.close()
                                
                            # Read from new thread
                            Thread.new {
                                # Read until pipe closes
                                until (rawLine = stdout.gets).nil? do
                                    line = rawLine.chomp() # Get rid of trailing newline
                                    @app.logger.info(line)
                                end
                                @app.logger.debug "Read thread ended"
                            }

                            # Thread that waits for process to exit
                            @thread = Thread.new {
                                # Join is necessary or else the pipes will just swallow all data.
                                # But, we can put the join in its own thread and not block up the main program
                                thr.join
                                
                                # join returns when process finishes
                                @pid = nil
                                @app.logger.info "Process terminated."
                            }
                            
                            @app.logger.debug "Finished starting"
                        # For anything other than windows, use a PTY
                        else
                            @app.logger.debug "Using PTY for IO"
                            # Have to use PTYs because *SOME* miners don't know how to talk to a pipe
                            require 'pty'

                            # Adpated from https://ruby-doc.org/stdlib-2.2.3/libdoc/pty/rdoc/PTY.html
                            master, slave = PTY.open
                            @pid = spawn(cmd, :chdir => @app.workingDir, :in=>slave, :out=>slave, :err=>slave)
                            slave.close    # Don't need the slave

                            # Thread to read from process
                            @thread = Thread.new {
                                begin
                                    # Read until pipe closes
                                    until (rawLine = master.gets()).nil? do
                                        line = rawLine.chomp() # Get rid of trailing newline
                                        @app.logger.info(line)
                                    end
                                rescue e
                                    @app.logger.warn "Exception in read thread: #{e}"
                                ensure
                                    @pid = nil
                                    master.close()
                                    @app.logger.info "Process ended."
                                end
                            }

                        end
                    rescue Errno::ENOENT => e
                        @app.logger.fatal "Unable to run application: #{e.message()}"
                    rescue Exception => e
                        @app.logger.error "Exception starting process."
                        @app.logger.error "#{e.class}: #{e.message()}"
                        @app.logger.error e.backtrace.join("\n\t")
                    end
                else
                    @app.logger.error "Unable to start, working directory does not exist."
                end
            end
        end
        
        def stop()
            if (started?())
                @app.logger.info "Termining #{@app.id}..."
                
                # Process.kill() is currently broken on windows.
                # See https://blog.simplificator.com/2016/01/18/how-to-kill-processes-on-windows-using-ruby/
                if (Gem.win_platform?)
                    if (!system("taskkill /pid #{@pid}", :out => File::NULL, :err => File::NULL))
                        # Some processes must be forcefully killed
                        if (!system("taskkill /f /pid #{@pid}", :out => File::NULL, :err => File::NULL))
                            @app.logger.error "Unable to stop application."
                        end
                    end
                else
                    # Kill process
                    Process.kill("TERM", @pid)
                end
                
                @app.logger.info "#{@app.id} stopped."
            end
            
            @pid = nil
            @thread = nil
        end
        
        def started?()
            # Signal 0 checks if process is alive
            #return Process.kill(@pid, 0)
            return @thread != nil
        end
        
        # Checks if the process is alive and running
        def alive?()
            if (started?)
                # Process.kill(0) does not work on windows
                if (Gem.win_platform?)
                    # Use tasklist CMD to check.  Slow but only reasonable way I've found under windows
                    system("tasklist /FI \"PID eq #{@pid}\"", :out => File::NULL, :err => File::NULL)
                else
                    # Magic inlining from https://stackoverflow.com/a/32513298
                    #  Works because we expect an exception and don't care what it is
                    !!Process.kill(0, @pid) rescue false
                end
            end
            
            return false
        end
        
        # Blocks the calling thread until app exits
        def waitForTerminate()
            if (started?)
                # wait for the monitor thread to close
                @thread.join
            end
        end
        
        # If false parent application will not exit until child application stops
        def daemon=(daemon)
            if (@thread != nil)
                @thread.daemon = daemon
            end
        end
        
        # If true, child application will be terminated when parent stops
        def killOnExit=(koe)
            if (koe)
                Watchdog.addFinalizer(@finalizer)
            else
                Watchdog.removeFinalizer(@finalizer)
            end
        end
    end
    
    def self.logger()
        if (@@logger == nil)
            @@logger = Log.createLogger("Applications")
        end
        return @@logger
    end
    
    def self.getApp(id)
        return @@applications[id.to_s]
    end
    
    def self.loadApps()
        Config.applications.each {|id, json|
            id = id.to_s
            
            app = App.createFromJSON(id, json)
            if (app != nil)
                @@applications[id] = app
            end
        }
    end
end