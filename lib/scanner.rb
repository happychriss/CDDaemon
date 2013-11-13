require_relative '../lib/support'
require 'rest-client'

class Scanner

  include Support

  def initialize
    @doc_name_index='000'
    @scanned_documents=Array.new
    @doc_name_prefix=File.join(Dir.tmpdir, "cdc_#{Time.now.strftime("%Y-%m-%d-%H%M%S")}_")
    @scann_converter_running=false
  end

  ############## DRB Commands - Called from remote

  def scanner_list_devices
    puts "**List Devices**"
    device_list=Hash.new

    # ["Canon LiDE 35/40/50", "genesys:libusb:001:004", "FUJITSU ScanSnap S300", "epjitsu:libusb:002:005"]
    device_string=%x[scanimage -f"%v %m|%d|"].split('|')
    0.step(device_string.count-1, 2) { |i| device_list[device_string[i]]=device_string[i+1]; puts "Device: #{device_string[i]}" }

    return device_list

  end

  def scanner_start_scann(device, color)
    begin
    scanner_status_update("Start for device #{device} and color: #{color}")
    scann_command=scanner_build_command(device, color)

    ### File Conversion Thread
    @convert_upload_thread=convert_upload_thread unless @scann_converter_running

    result = %x[#{scann_command}] ############ HERE IS THE SCANNING

    scanner_status_update("Ready:#{result}",true) ## true to say we are running to scan new data

    return result
    rescue => e
      puts "************ ERROR *****: #{e.message}"
      raise
    end
  end



######################################################################
    def convert_upload_thread

      @scann_converter_terminate=false
      @scann_converter_running=true
      sleep_count=0

      t=Thread.new do

        until @scann_converter_terminate do
          sleep 0.5; sleep_count=sleep_count+0.5
          if sleep_count>50 then
            @scann_converter_terminate=true
          end

          scanned_files=Dir.glob(@doc_name_prefix+"*.scanned.ppm").sort_by { |f| File.basename(f) }

          scanned_files.each do |f_scanned_ppm|
            sleep_count=0

            if not system "empty-page -p 0.6 -i '#{f_scanned_ppm}'" then
              f=f_scanned_ppm.split('.')[0] #name without extension

              if @scanned_documents.index(f).nil?
                scanner_status_update("Cleaning")

                res1 = %x[unpaper -v --overwrite  --mask-scan-size 120 --post-size a4 --sheet-size a4 --no-grayfilter --no-blackfilter  '#{f_scanned_ppm}' '#{f}.unpaper.ppm']
                raise "Error unpaper - #{res1}" unless res1[0..10] == "unpaper 0.4"

                res2 = %x[convert '#{f}.unpaper.ppm' '#{f}.converted.jpg']
                raise "Error convert - #{res2}" unless res2==''

                res3 = %x[convert '#{f}.converted.jpg' -resize 350x490\! jpg:'#{f}.converted_small.jpg']
                raise "Error convert - #{res3}" unless res3==''

                scanner_status_update("Upload to server")
                @scanned_documents.push(f)

                RestClient.post CD_SERVER+'/upload_jpg', {:page => {:upload_file => File.new(f+".converted.jpg", 'rb'), :source => 1}, :small_upload_file => File.new(f+".converted_small.jpg", 'rb')}, :content_type => :json, :accept => :json

                res4 = FileUtils.rm "#{f}.unpaper.ppm"

                scanner_status_update(" #{@scanned_documents.count()} documents processed.")

              end
            end
            res6=FileUtils.rm f_scanned_ppm
          end

          puts "--check for new work"

        end

        @scann_converter_running=false
        puts '-- terminate convert thread -no new work'
        sleep 0.5
      end
      t.abort_on_exception = true
      t
    end


    def scanner_build_command(device, color)
      @result='-'

      @doc_name_index=@doc_name_index.next
      scan_tmp_file=@doc_name_prefix+"_#{@doc_name_index}_%03d.scanned.ppm"
      mode='Lineart' if not color
      mode='Color' if color
      resolution='300'
#    resolution='600' if @resolution_high.checked?
      source="'ADF Duplex'"
#    source="'ADF Front'" if @scan_only

## Scan file will look like:


      scan=""

      ["scanimage",
       "--device=" + device,
       "--mode=" + mode,
       "--resolution=" + resolution,
       "--format=" + "ppm",
       "--batch=" + scan_tmp_file,
       "--source="+ source,
       "2>&1"].each { |c| scan=scan+c+" " }

      puts "Scan Command: #{scan}"

      return scan

    end

    def scanner_status_update(message,scan_complete=FALSE)
      puts "DRBSCANNER: #{message}"
      RestClient.post CD_SERVER+'/scan_status', {:message => message, :scan_complete => scan_complete}, :content_type => :json, :accept => :json
    end


  end