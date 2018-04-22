#-----------------------------------------
# Executes a miner in a different process
#-----------------------------------------

# Not required, because worker requires this
#require_relative('worker')
require 'util/log'

class Executor
    def initialize()
        @job = nil      
        @running = false # Not synchronized, so be careful when accessing
        @pid = nil
        
        @workerLogger = nil
        @minerLogger = nil
    end
    
    attr_reader :job, :running, :pid
    
    def start(job)
        #@running = true
        
        # don't start if already running
        if (!alive?())
            @workerLogger = job.worker.logger        
            @job = job
       
            @workerLogger.info("Starting #{@job.miner.name} on #{@job.coin.name}.")
            
            # TODO forward to Worker logger
            @minerLogger = Log.createLogger("#{@workerLogger.progname}/job.miner.id", toConsole: Config.settings[:show_miner_output])
       
            # Create subprocess (INSECURE - uses shell, so don't pass any external data in).
            cmd = "#{@job.miner.exec} #{@job.miner.args(job)}"
            @workerLogger.debug("Command: #{cmd}")

            # Make sure working dir exists
            if (Dir.exist? @job.miner.path)
                begin
                    # Linux and windows miners behave differently and need different process code.
                    if (Gem.win_platform?)
                        @workerLogger.debug("Using pipes for IO")
                        
                        require 'open3'
                        
                        # This method doesn't work for programs that use TTYs
                        # Start the process
                        #BUG: if path does not exist then ruby will exit with no error
                        stdin, stdout, thr = Open3.popen2e(cmd, :chdir => @job.miner.path)
                        @pid = thr.pid # pid of the started process.
                        @running = true
                        
                        # Close write pipe
                        stdin.close()
                            
                        # Read from new thread
                        Thread.new {
                            # Read until pipe closes
                            until (rawLine = stdout.gets).nil? do
                                line = rawLine.chomp() # Get rid of trailing newline
                                @minerLogger.info(line)
                            end
                            @workerLogger.debug("Read thread ended")
                        }

                        Thread.new {
                            # Join is necessary or else the pipes will just swallow all data.
                            # But, we can put the join in its own thread and not block up the main program
                            thr.join
                            
                            # join returns when process finishes
                            @running = false
                            @workerLogger.info("Process terminated.")
                        }
                        
                        @workerLogger.debug("Finished starting")
                    # For anything other than windows, use a PTY
                    else
                        @workerLogger.debug("Using PTY for IO")
                        # Have to use PTYs because *SOME* miners don't know how to talk to a pipe
                        require 'pty'

                        # Adpated from https://ruby-doc.org/stdlib-2.2.3/libdoc/pty/rdoc/PTY.html
                        master, slave = PTY.open
                        @pid = spawn(cmd, :chdir => @job.miner.path, :in=>slave, :out=>slave, :err=>slave)
                        slave.close    # Don't need the slave
                        
                        @running = true

                        # Thread to read from process
                        Thread.new {
                            begin
                                # Read until pipe closes
                                until (rawLine = master.gets()).nil? do
                                    line = rawLine.chomp() # Get rid of trailing newline
                                    @minerLogger.info(line)
                                end
                            rescue e
                                @workerLogger.warn("Exception in read thread: #{e}")
                            ensure
                                @running = false
                                master.close()
                                @workerLogger.info("Process ended.")
                            end
                        }

                    end
                rescue e
                    @workerLogger.error "Exception starting process."
                    @workerLogger.error e.message()
                    @workerLogger.error e.backtrace.join("\n\t")
                end
            else
                @workerLogger.error "Unable to start, working directory does not exist."
            end
        end
    end
    
    def stop()
        if (alive?())
            @workerLogger.info("Termining #{@job.miner.name}...")
            
            # Process.kill() is currently broken on windows.
            # See https://blog.simplificator.com/2016/01/18/how-to-kill-processes-on-windows-using-ruby/
            if (Gem.win_platform?)
                if (!system("taskkill /pid #{@pid}"))
                    # Some processes must be forcefully killed
                    if (!system("taskkill /f /pid #{@pid}"))
                        @workerLogger.error("Unable to stop miner!")
                    end
                end
            else
                # Kill process
                Process.kill("TERM", @pid)
            end
            
            #Process.wait(@pid)
            @workerLogger.info("#{@job.miner.name} stopped.")
        end
        @job = nil
        @workerLogger = nil
        @minerLogger = nil
        @pid = nil
        @running = false
    end
    
    def alive?()
        # Signal 0 checks if process is alive
        #return Process.kill(@pid, 0)
        return @running
    end
end
