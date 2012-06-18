#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'cmus'

LOLastfm.define_checker :cmus do
	settings.default[:socket] = '~/.cmus/socket'

	@cmus = Cmus::Controller.new(settings[:socket])

	hint do |title|
	end
end
