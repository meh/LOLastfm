#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

LOLastfm.define_checker :process do
	settings.default[:every] = 5

	set_interval settings[:every] do
		if status == :stopped
			if @last == :playing

			end
		else
		end

		@last = status
	end

	hint do |path|
		if @hint && path != @hint
			next unless listened path: path
		end

		next unless now_playing path: path

		@hint = path
	end
end
