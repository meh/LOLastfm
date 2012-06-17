#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

class LOLastfm

class Checker
	attr_reader :fm, :name, :settings

	def initialize (fm, name, settings = {}, &block)
		@fm       = fm
		@name     = name
		@settings = settings
		@block    = block
	end

	def start
		instance_exec @block
	end

	def hint (*args, &block)
		if block
			@hint = block
		else
			@hint.call(*args)
		end
	end
end

end
