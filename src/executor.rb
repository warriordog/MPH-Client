#-----------------------------------------
# Executes a miner in a different process
#-----------------------------------------

# Have to use PTYs because *SOME* miners don't know how to talk to a pipe
require 'pty'

# Not required, because worker requires this
#require_relative('worker')
require_relative 'log'

class Executor
    def initialize()
        @job = nil      
        @running = false # Not synchronized, so be careful when accessing
        @pid = nil
        @logger = nil
    end
    
    attr_reader :job, :running, :pid
    
    def start(job)
        #@running = true
        
        # don't start if already running
        if (!alive?())
            @job = job
            @logger = job.worker.logger
            
            @logger.info("Starting #{@job.miner.name} on #{@job.coin.name}.")
       
            # Create subprocess (INSECURE - uses shell, so don't pass any external data in.
            cmd = "#{@job.miner.exec} #{@job.miner.args(job)}"
            @logger.debug("Command: #{cmd}")

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
                        @logger.info(line)
                    end
                rescue e
                    @logger.warn("Exception in read thread: #{e}")
                ensure
                    @running = false
                    master.close()
                    @logger.info("Process ended.")
                end
            }
# This method doesn't work for programs that use TTYs
=begin
            # Start the process
            stdin, stdout, thr = Open3.popen2e(cmd, :chdir => @algorithm.miner.path)
            #stdout.sync = true
            @pid = thr.pid # pid of the started process.
            @running = true
                
            # Read from new thread
            Thread.new {
                # Read until pipe closes
                until (rawLine = stdout.gets).nil? do
                    line = rawLine.chomp() # Get rid of trailing newline
                    @logger.info(line)
                end
                @logger.debug("Read thread ended")
            }

            Thread.new {
                # Join is necessary or else the pipes will just swallow all data.
                # Not even a while loop will work, wtf!
                # But, we can put the join in its own thread and not block up the main program
                thr.join
                
                # join returns when process finishes
                @running = false
                @logger.info("Process terminated.")
            }
            
            @logger.debug("Finished starting")
=end
        end
    end
    
    def stop()
        if (alive?())
            @logger.info("Termining #{@job.miner.name}...")
            # Kill process
            Process.kill("TERM", @pid)
            Process.wait(@pid)
            @logger.info("#{@job.miner.name} stopped.")
        end
        @job = nil
        @logger = nil
        @pid = nil
        @running = false
    end
    
    def alive?()
        # Signal 0 checks if process is alive
        #return Process.kill(@pid, 0)
        return @running
    end
end
