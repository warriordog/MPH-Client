#
# System for parsing a string and injecting arguments
#

require 'util/log'

module Args
	# Fallback module logger
    @@logger = nil
	
	# Finds and replaces arguments in a string
	#   Arguments are identified in string by $(IDENTIFIER)
	#     $() constructions can be escaped like: \$(not an identifier)
	#     IDENTIFIER should be a string key in args
	#   A logger can be passed in to report unknown identifiers
	#     Pass in nil to disable logging
	#   A block can be passed in to process each detected argument
	def self.injectArgs(string, args, logger = @logger)
		# Make sure string has contents
		if (string == nil || string.empty?)
			return string
		end
		
		# Make sure there are args to work with
		if (args == nil || args.empty?)
			return string
		end
	
		# Process the string
		return string.gsub(/(?<!\\)\$\(([\w.]*)\)/) {|match|
			# Make sure that argument name is valid
			if (args.include? $1)
				# Get the value
				value = args[$1]
			
				# Make sure we actually have a block before trying to yield
				if (block_given?)
					# Allow block to process argument
					yield($1, value)
				else
					# No block so just return
					value.to_s
				end
			else
				# Make sure logger has not be disabled
				if (logger != nil)
					# Warn if there is no match
					logger.warn "Unknown event variable '#{$1}'."
				end
				
				# Leave the original text in place
				match
			end
		}
	end
    
    def self.logger()
        if (@@logger == nil)
            @@logger = Log.createLogger("Util/Args")
        end
        return @@logger
    end
end