#
# Watchdog system
#

require "util/log"
 
module Watchdog
    
	# Module logger
    @@logger = nil
    
    # List of non-daemon threads
    @@nonDaemonThreads = []
    
    # List of finalizers
    @@finalizers = []

    # Eats the main thread and waits for exit
    #   Block will be called from the new "main thread"
    def self.eatMainThread(&block)
    
        # Set up logger
        @@logger = Log.createLogger("Watchdog")
        @@logger.debug "Watchdog active"
    
        # Create and start main thread
        newMain = Thread.new {
            if (block != nil)
                block.call
            end
        }
        newMain.daemon = true
    
        # Wait for exit
        while (!@@nonDaemonThreads.empty?)
            @@nonDaemonThreads.each {|t|
                begin
                    # Wait for exit
                    t.join
                rescue Exception => e
                    @@logger.error "Exception waiting for thread, it will be un-daemonized."
                    @@logger.error e
                    @@logger.error e.backtrace.join("\n\t")
                    
                    @@nonDaemonThreads.delete t
                end
            }
        end
        
        # Call finalizers
        @@finalizers.each {|f|
            begin
                # Execute finalizer
                f.call
            rescue Exception => e
                @@logger.error "Exception in finalizer"
                @@logger.error e
                @@logger.error e.backtrace.join("\n\t")
            end
        }
    end

    def self.addDaemonThread(thread)
        if (thread != nil)
            @@nonDaemonThreads << thread
        end
    end
    
    def self.removeDaemonThread(thread)
        if (thread != nil)
            @@nonDaemonThreads -= thread
        end
    end
    
    def self.addFinalizerBlock(&block)
        self.addFinalizer(block)
    end
    
    def self.addFinalizer(finalizer)
        if (finalizer != nil)
            @@finalizers << finalizer
        end
    end
    
    def self.removeFinalizer(finalizer)
        if (finalizer != nil)
            @@finalizers.delete finalizer
        end
    end
end
# Inject daemon code to thread
Thread.class_eval {
    @is_daemon = true
    
    def daemon=(is_daemon)
        if (is_daemon != @is_daemon)
            @is_daemon = is_daemon
            
            # Register or de-register
            if (is_daemon)
                Watchdog.addDaemonThread(self)
            else
                Watchdog.removeDaemonThread(self)
            end
        end
    end
    
    def self.daemon()
        return @is_daemon
    end
}