module Support

  def check_program(command)
    puts "Check command #{command}.."
    if %x[which '#{command}']=='' then
      raise "Processor-Client *#{command}* command missing"
    else
      puts "..OK"
    end

  end

  def me_alive?
    return true
  end



end

