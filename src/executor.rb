#-----------------------------------------
# Executes a miner in a different process
#-----------------------------------------

class Executor
    def initialize()
        @algorithm = nil        
        @running = false
        @pid = nil
    end
    
    attr_reader :algorithm, :coin, :running
    
    def start(algorithm, settings, worker, coin)
        @running = true
        
        # don't start if already running
        if (@pid == nil)
            @algorithm = algorithm
            # Create subprocess (INSECURE - uses shell, so don't pass any external data in.
            cmd = "./#{@algorithm.miner.exec} #{@algorithm.miner.args(settings, worker, coin)}"
            @pid = spawn(cmd, :chdir => @algorithm.miner.path)
        end
    end
    
    def stop()
        if (@pid != nil)
            # Kill process
            Process.kill("TERM", @pid)
            Process.wait(@pid)
        end
        @pid = nil
        @running = false
    end
    
    def alive()
        # Signal 0 checks if process is alive
        return Process.kill(@pid, 0)
    end
end
