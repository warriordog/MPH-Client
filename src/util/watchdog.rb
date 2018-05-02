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
        # Set name of main thread
        Thread.current.name = "watchdog"
    
        # Set up logger
        @@logger = Log.createLogger("Watchdog")
        @@logger.debug "Watchdog active"
    
        # Create and start main thread
        newMain = Thread.new {
            if (block != nil)
                block.call
            end
        }
        newMain.name = "main"
        newMain.daemon = false
    
        # Wait for exit
        while (!@@nonDaemonThreads.empty?)
            @@nonDaemonThreads.each {|t|
                begin
                    @@logger.debug {"Waiting for '#{t.name}'"}
                    
                    # Wait for exit
                    t.join
                    
                    # Delete thread when done
                    @@nonDaemonThreads.delete t
                rescue Interrupt => e
                    # Ignore this - it comes from Ctrl-C and the like
                    # Don't delete thread yet because we may need to wait more
                rescue Exception => e
                    @@logger.error "Exception waiting for thread, it will be un-daemonized."
                    @@logger.error e.message
                    @@logger.error e.backtrace.join("\n\t")
                    
                    # Delete from error
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
                @@logger.error e.message
                @@logger.error e.backtrace.join("\n\t")
            end
        }
    end

    def self.addNonDaemonThread(thread)
        if (thread != nil)
            @@nonDaemonThreads |= [thread]
        end
    end
    
    def self.removeNonDaemonThread(thread)
        if (thread != nil)
            @@nonDaemonThreads.delete thread
        end
    end
    
    def self.addFinalizerBlock(&block)
        self.addFinalizer(block)
    end
    
    def self.addFinalizer(finalizer)
        if (finalizer != nil)
            # Add if not present
            @@finalizers |= [finalizer]
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
            if (!is_daemon)
                Watchdog.addNonDaemonThread(self)
            else
                Watchdog.removeNonDaemonThread(self)
            end
        end
    end
    
    def self.daemon()
        return @is_daemon
    end
}