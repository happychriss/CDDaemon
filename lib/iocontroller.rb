require_relative '../lib/support'
require 'sunxi_gpio/pin'


class Iocontroller

  include Support

  def initialize(web_server_uri,options)
    @web_server_uri=web_server_uri
    @gpio_server_uri="druby://#{options[:gpio_server]}:#{options[:gpio_port]}"    #URI='druby://10.237.48.91:8780'

    puts "********* Init Iocontroll Daemon connect to webserver: #{@web_server_uri} and DRB connecting to gpio-server #{@gpio_server_uri}*******"

    ## Connect to gpio_server

    puts "*** Connect to:#{@gpio_server_uri}"
    @gpio_pins = DRbObject.new_with_uri(@gpio_server_uri)
    puts "*** DONE"

    @led_green=@gpio_pins.new_pin(pin: :PH07, direction: :out)
    @led_yellow=@gpio_pins.new_pin(pin: :PH20, direction: :out)

    @led_yellow.on
    sleep(1)
    @led_yellow.off

    @start_copy_button = @gpio_pins.new_pin(pin: :PI15, direction: :in, pull: :up)

  end


  ################## Called from DRB ###################################################

  def set_ok_status_led(value)
    puts "Set status GREEN:#{value}"
    @led_green.on if value==:on
    @led_green.off if value==:off
  end

  def set_warning_status_led(value)
    puts "Set status YELLOW:#{value}"
    @led_yellow.on if value==:on
    @led_yellow.off if value==:off
  end

  def blink_ok_status_led
    t=Thread.new do
    @led_green.on
    sleep(4)
    @led_green.off
      end
  end

  def watch_scanner_start_button
    new_thread = Thread.new do
      @start_copy_button.client_watch(0) do
        RestClient.post @web_server_uri+'/start_scanner_from_hardware', {}, :content_type => :json, :accept => :json
      end
    end

  end

end