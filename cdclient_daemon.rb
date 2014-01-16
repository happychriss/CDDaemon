###  Server Daemon to convert data on a more performant server - called via distributed ruby DRB
require 'rubygems' # if you use RubyGems
require 'daemons'
require 'drb'
require 'drb/acl'
require 'tempfile'

require_relative 'init'
require_relative './lib/converter'
require_relative './lib/scanner'
require_relative './lib/support'

TEST=true


def StartDrb(uri, object)
  puts "Start DRB service for: #{object.class.name} with uri: #{uri}"
  DRb.start_service(uri, object) # replace localhost with 0.0.0.0 to allow conns from outside
  sleep(1)
  RestClient.post CD_SERVER+'/status_drb', {:drb_server => object.class.name, :running => true}, :content_type => :json, :accept => :json
end

def StopDrb(uri, object)
  puts "Stop DRB service for: #{object.class.name} with uri: #{uri}"
  RestClient.post CD_SERVER+'/status_drb', {:drb_server => object.class.name, :running => false}, :content_type => :json, :accept => :json
end

def run_drb_daemons
  begin
    scanner=Scanner.new
    converter=Converter.new
    StartDrb(URI_SCANNER, scanner)
    StartDrb(URI_CONVERTER, converter)
    begin
      DRb.thread.join
    rescue Interrupt
    ensure
      StopDrb(URI_SCANNER, scanner)
      StopDrb(URI_CONVERTER, converter)
      sleep(1)
      DRb.stop_service
    end
  end
end

# ***************************************************************************************************

if TEST then
  run_drb_daemons
else
  Daemons.run_proc("DRbProcessorRemoveServer.rb", options = {:dir_mode => :normal, :ARGV => ARGV, :log_output => true, :on_top => true}) do

    $SAFE = 1 # disable eval() and friends

    acl = ACL.new(%w{deny all
                  allow localhost
                  allow 192.168.1.*}) ## from local subnet

    puts "In Daemons run_proc in remote mode on port 8999"

    ### abbyocr is using getcwd when converting pdf to pdf,Daemons des set this to "/". This result in core dump. Setting the directoy helps
    Dir.chdir(Dir.tmpdir)
    puts "Current Dir: "+Dir.pwd

    run_drb_daemons
  end
end

