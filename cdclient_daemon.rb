###  Server Daemon to convert data on a more performant server - called via distributed ruby DRB
require 'rubygems' # if you use RubyGems
require 'drb'
require 'drb/acl'
require 'tempfile'
require 'dnssd'
require 'optparse'
require 'socket'

require_relative './lib/converter'
require_relative './lib/scanner'
require_relative './lib/hardware'

require_relative './lib/support'


TEST=true


def terminate(options, web_server_uri)
  ### if terminated, say goodby to the server
  puts "Stop DRB service for: #{options[:service]}"
  RestClient.delete web_server_uri+"/connectors/#{options[:uid]}", {:content_type => :json, :accept => :json}
  sleep(1)
  exit
end



# Tries several times to connect to the webserver
def connect_to_webserver(drb_uri, options, web_server_uri,services,reply)
  try_counter=0; try_max=10

  loop do
    begin
      puts "#{Time.now} *** try connecting to : #{drb_uri}"
      sleep(rand*5)
      RestClient.post web_server_uri+'/connectors', {:connector => {:service => options[:service], :uri => drb_uri, :uid => options[:uid], :prio => options[:prio]}}, :content_type => :json, :accept => :json
      puts "*** connection succesfully established"
      return true
    rescue => e
      try_counter=try_counter+1
      puts "Failed with error:#{e.message} and try number:#{try_counter}"

      if try_counter==try_max
        services.delete(reply.fullname)
        DRb.stop_service
        puts "Disconnected from Service: #{reply.fullname}"
        return false
      end

    end
  end
end

def run_drb_daemons(options)


  browser = DNSSD::Service.new
  services = {}
  web_server_uri=''
  drb_uri="druby://#{Socket.gethostname}:#{options[:port]}"   ## Create uri of drb-service that is the current host and the port from the config file
  avahi_name="Cleandesk_#{options[:avahi_prefix]}" ## Create Avahi Service Name, this is the avahi service the daemon is looking for

  puts "****** Waiting for Service request avahi: #{avahi_name}"

  browser.browse '_cds._tcp' do |reply|

    if reply.flags.add? then

      puts "#{Time.now}: Found Service: #{reply.fullname}"

      if reply.name==avahi_name and services[reply.fullname].nil?

        services[reply.fullname] = reply

        ## Start DRB Service and connect to URI
        DNSSD::Service.new.resolve reply do |r|

          ## Create the uri of the web-server to sent confirmation, read from the service request
          web_server_uri="#{r.target}:#{r.port}"

          #generate Service Object for DRB
          service_obj=Object.const_get(options[:service]).new(web_server_uri, options)

          ### Start DRB Service
          puts "*** Providing service for: #{web_server_uri} via DRB: #{drb_uri} and  and subnet: #{options[:subnet]} ***"

          acl = ACL.new(%W(deny all
                           allow #{options[:subnet]}.*
                           allow localhost))

          DRb.install_acl(acl)
          DRb.start_service(drb_uri, service_obj)
          DRb.uri

          ### Ancounce Service to Server by sending a post request, trying it several times, as avahi service may be up and running before web-server is ready
          connect_to_webserver(drb_uri, options, web_server_uri,services,reply)

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
      puts "#{Time.now}: Lost Service: #{reply.fullname}"

      if reply.name==avahi_name and not services[reply.fullname].nil?

        ## check if server is down or just a short avahi problem (lost connection)
        begin
          puts "******* Lost CONFIGURED service for: #{reply.fullname}.. try reconnect to #{web_server_uri} *****************"
          sleep(1) ### give the server some time, assuming the network was down for a second  and trie to reconnect
          connect_to_webserver(drb_uri, options, web_server_uri,services,reply)
        end

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
  opts.on('-f', '--avahiprefix PREFIX_AVAHI', 'Avahi Search Prefix') { |v| options[:avahi_prefix] = v }

  ### option for scanner only
  opts.on('-i', '--unpaper_speed SPEED', 'Unpaper speed (y/n)') { |v| options[:unpaper_speed] = v }


  ### option for converter only only
  opts.on('-i', '--unpaper_speed SPEED', 'Unpaper speed (y/n)') { |v| options[:unpaper_speed] = v }


  ### option for gpioserver only, used by hardwares system to connect to gpio_server
  opts.on('-g', '--gpio_port PORT', 'Port of the gpio_server to connect to') { |v| options[:gpio_port] = v }
  opts.on('-h', '--gpio_server SERVER', 'Server of the gpio_server to connect to') { |v| options[:gpio_server] = v }

end.parse!

run_drb_daemons(options)
