### Starts a server for gpio access as sudo and anounces it service via ahahi, so other can query it and use it

require 'sunxi_server/drb_pin'
require 'drb'
require 'drb/acl'

Signal.trap("INT") do
  puts "\nTerminated"
  $stdout.flush
  exit
end


port=0; subnet=''
ARGV.each_with_index do |a, i|
  port=ARGV[i+1].to_i if a=='-p'
  subnet=ARGV[i+1].to_i if a=='-s'
end

########## Start DRB-SERVER ####################################################

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

puts "...done"

# Wait for the drb server thread to finish before exiting.
DRb.thread.join
