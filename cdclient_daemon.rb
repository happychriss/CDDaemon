###  Server Daemon to convert data on a more performant server - called via distributed ruby DRB
require 'rubygems' # if you use RubyGems
require 'daemons'
require 'drb'
require 'drb/acl'
require 'tempfile'
require 'dnssd'
require 'optparse'
require 'socket'

require_relative './lib/converter'
require_relative './lib/scanner'
require_relative './lib/support'

TEST=true


def terminate(options, web_server_uri)
  ### if terminated, say goodby to the server
  puts "Stop DRB service for: #{options[:service]}"
  RestClient.delete web_server_uri+"/connections/#{options[:uid]}", {:content_type => :json, :accept => :json}

  sleep(1)
  DRb.stop_service

end


def run_drb_daemons(options)


  browser = DNSSD::Service.new
  services = {}

  #generacte Service Object, Scanner/Converter/Gpio

  service_obj=Object.const_get(options[:service])
  service_obj.new(options[:uid])

  drb_uri=""
  web_server_uri=""

  puts "Waiting for Service request for service: #{options[:service]}"

  browser.browse '_cds._tcp' do |reply|

    if reply.flags.add? then
      puts "Found Service: #{reply}"

      if reply.name==options[:service] and services[reply.fullname].nil?

        services[reply.fullname] = reply

        ## Start DRB Service and connect to URI
        DNSSD::Service.new.resolve reply do |r|

          ## Create uri of drb-service that is the current host and the port from the config file
          drb_uri="druby://#{Socket.gethostname}:#{options[:port]}"

          ## Create the uri of the web-server to sent confirmation, read from the service request
          web_server_uri="#{r.target}:#{r.port}"

          ### Start DRB Service
          puts "*** Starting Service:#{reply.fullname} on DRF: #{drb_uri} and connecting to: #{web_server_uri} ***"

          acl = ACL.new(["deny", "all", "allow", "localhost", "allow", "#{options[:subnet]}"])
          DRb.install_acl(acl)
          DRb.start_service(drb_uri, service_obj)

          ### Ancounce Service to Server
          sleep(1)
          RestClient.post web_server_uri+'/connections', {:connection => {:service => options[:service], :uri => drb_uri, :uid => options[:uid], :prio => options[:prio]}}, :content_type => :json, :accept => :json

          break unless r.flags.more_coming?
        end

        Thread.abort_on_exception = true
        trap 'INT' do
          terminate(options, web_server_uri)
        end
        trap 'TERM' do
          terminate(options, web_server_uri)
        end


      end

    else
      puts "Lost Service: #{reply}"
      if not services[reply.fullname].nil?
        services.delete(reply.fullname)
        puts "Disconnected from Service: #{reply.fullname}"
      end
    end

  end


end

# *************************************************************************************************** *************
# *************************************************************************************************** *************
# *************************************************************************************************** *************


options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: cdcclient_daemon.rb [options]"
  opts.on('-s', '--Service SERVICE', 'Service [converter,scanner,gpio]') { |v| options[:service] = v }
  opts.on('-u', '--uid NUMBER', 'Unique ID of the service') { |v| options[:uid] = v }
  opts.on('-r', '--prio NUMBER', 'Prio, high number, high prio') { |v| options[:prio] = v }
  opts.on('-n', '--subnet SUBNET', 'Subnet ACL, e.g. 192.168.1.*') { |v| options[:subnet] = v }
  opts.on('-p', '--port PORT', 'Port where the DRB-Service is offered, sent to the server') { |v| options[:port] = v }
end.parse!


if TRUE then
  run_drb_daemons(options)
else
  Daemons.run_proc("DRbProcessorRemoveServer.rb", options = {:dir_mode => :normal, :ARGV => ARGV, :log_output => true, :on_top => true}) do

    $SAFE = 1 # disable eval() and friends

    puts "In Daemons run_proc in remote mode on port 8999"

    ### abbyocr is using getcwd when converting pdf to pdf,Daemons des set this to "/". This result in core dump. Setting the directoy helps
    Dir.chdir(Dir.tmpdir)
    puts "Current Dir: "+Dir.pwd

    run_drb_daemons(options)
  end
end