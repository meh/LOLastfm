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
	class Settings
		attr_reader :default

		def initialize (checker, data)
			@data    = data.to_hash
			@default = {}
		end

		def respond_to_missing? (id)
			@data.respond_to?(id)
		end

		def method_missing (id, *args, &block)
			@default.merge(@data).__send__ id, *args, &block
		end
	end

	attr_reader :fm, :name, :settings

	def initialize (fm, name, settings = nil, &block)
		raise LocalJumpError, 'no block given' unless block

		@fm       = fm
		@name     = name
		@settings = Settings.new(self, settings || {})
		@block    = block

		@timers = []
	end

	def start
		instance_eval &@block
	end
	
	def stop
		@timers.each {|timer|
			clear_timeout(timer)
		}
	end

	def hint (*args, &block)
		if block
			@hint = block
		else
			@hint.call(*args) if @hint
		end
	end

	def set_timeout (*args, &block)
		EM.schedule {
			@timers << EM.add_timer(*args, &block)
		}
	end

	def set_interval (*args, &block)
		EM.schedule {
			@timers << EM.add_periodic_timer(*args, &block)
		}
	end

	def clear_timeout (what)
		EM.schedule {
			EM.cancel_timer(what)
		}
	end
end

end
