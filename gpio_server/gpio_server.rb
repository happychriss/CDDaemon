### Starts a server for gpio access as sudo and anounces it service via ahahi, so other can query it and use it

require 'sunxi_server/drb_pin'
require 'drb'
require 'drb/acl'
require 'daemons'
require 'optparse'


class gpio_app

def initialize(args)
	super(self.class)
	@options = OpenStruct.new(:daemonize => true)
	opts = OptionParser.new do |opts|
	opts.banner = 'Usage: myapp [options]'
	opts.separator ''
	opts.on('-N', '--no-daemonize', "Don't run as a daemon") do
	@options.daemonize = false
end
end
@args = opts.parse!(args)
end

end

	########## Start DRB-SERVER ####################################################

	puts options

	port=options[:port]
	subnet=options[:subnet]

	drb_uri="druby://localhost:#{port}"
	#URI='druby://10.237.48.91:8780'

	puts "****** Start DRB Gpio-Server on #{drb_uri}*** for subnet #{subnet}"


	 list = %W[
		  deny all
		  allow localhost
		  allow #{subnet}.*
	]

	acl = ACL.new(list, ACL::DENY_ALLOW)
	DRb.install_acl(acl)


	front_object=SunxiServer::DRB_PinFactory.new
	$SAFE = 1 # disable eval() and friends
	DRb.start_service(drb_uri, front_object)

	puts "Service started"

	# Wait for the drb server thread to finish before exiting.
end


#############################################################################################



Daemons.run_proc("DRbGpio.rb", options = {:ARGV => ARGV, :log_output => true, :log_dir => '//home/cds/CDDaemon/gpio_server' }) do


doptions = {}

parser=OptionParser.new do |opts|
  opts.banner = "Usage: cdcclient_daemon.rb [options]"
  opts.on('-n', '--subnet SUBNET', 'Subnet ACL, e.g. 192.168.1.*') { |v| doptions[:subnet] = v }
  opts.on('-p', '--port PORT', 'Port where the DRB-Service is offered, sent to the server') { |v| doptions[:port] = v }
end



puts "my options: #{ARGV}"
puts "my doptions: #{doptions}"

$SAFE = 1 # disable eval() and friends

puts "In Daemons run_proc starting with options:#{doptions}"

run_drb_daemons(doptions)

end
