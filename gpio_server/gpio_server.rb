### Starts a server for gpio access as sudo and anounces it service via ahahi, so other can query it and use it

require 'sunxi_server/drb_pin'
require 'drb'
require 'drb/acl'
require 'daemons'
require 'optparse'


class GpioApp

  def initialize(args)

    @port=0
    @subnet=''

    @args_daemon=args[0] # arguments for the contolling daemon / start / stop

    args.shift(2) ## remove daemon options
    OptionParser.new do |opts|
      opts.on('-p', '--port PORT', "DRB Port to listen") { |v| @port = v }
      opts.on('-s', '--subnet SUBNET', "Access List ACL") { |v| @subnet = v }
    end.parse(args)

  end

  def run


    Daemons.run_proc("gpio_server",:ARGV => [@args_daemon],:log_output => true) do

    ########## Start DRB-SERVER ####################################################


    drb_uri="druby://localhost:#{@port}"
    #URI='druby://10.237.48.91:8780'

    puts "****** Start DRB Gpio-Server on #{drb_uri}*** for subnet #{@subnet}"


    list = %W[
		  deny all
		  allow localhost
		  allow #{@subnet}.*
	]

    acl = ACL.new(list, ACL::DENY_ALLOW)

    front_object=SunxiServer::DRB_PinFactory.new

    DRb.install_acl(acl)

    DRb.start_service(drb_uri, front_object)

    puts "Service started"

    sleep

    # Wait for the drb server thread to finish before exiting.
      end
  end



end

#############################################################################################

gpio_app=GpioApp.new(ARGV)
gpio_app.run

