#-----------------------------------------------------------
# Logging system (basically a wrapper around Ruby's logger)
#-----------------------------------------------------------

require 'logger'

module Log

    # Log directory
    @@logDir = "./log"
    
    # Splits a logging output into two or more other outputs
    # Based on https://stackoverflow.com/a/6407200
    class IOSplitter
        def initialize(*outputs)
            @outputs = outputs
        end

        def write(*args)
            @outputs.each {|o| o.write(*args)}
        end

        def close
            @outputs.each {|o| o.close()}
            @outputs = []
        end
    end

    def self.logDir()
        return @@logDir
    end
    
    def self.logDir=(val)
        @@logDir = val
    end

    def self.createLogPath(logDir, name)
        if (!Dir.exist?(logDir))
            Dir.mkdir(logDir)
        end
        return "#{logDir}/#{name}.log"
    end

    def self.createLogDev(name, toFile, toConsole)
        logPath = createLogPath(@@logDir, name)
    
        if (toFile && toConsole)
            logFile = File.open(logPath, 'a')
            return IOSplitter.new(STDOUT, logFile)
        elsif (toFile)
            return logPath
        elsif (toConsole)
            return STDOUT
        else
            return nil
        end
    end

    def self.createLogger(name, toFile = true, toConsole = true)
        logger =  Logger.new(createLogDev(name, toFile, toConsole))
        logger.progname = name 
        logger.formatter = proc {|sev, dt, nm, msg| "[#{dt.strftime("%Y-%m-%d(%a) %H:%M:%S.%L")}][#{sev}][#{nm}] #{msg}\n"}
        return logger;
        
    end
    
    def self.changeLogMode(logger, toFile, toConsole)
        logDev = createLogDev(logger.progname, toFile, toConsole)
        logger.reopen(logDev)
    end
end
