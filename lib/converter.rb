require_relative '../lib/support'

class Converter

  ### this part is running on the remove server (desktop) not on the qnas, should have convert and pdftotext installed

  include Support

  def run_conversion(data, mime_type)

    begin

      f = Tempfile.new("cd2_remote")
      f.write(data)
      f.untaint #avoid ruby insecure operation: http://stackoverflow.com/questions/12165664/what-are-the-rubys-objecttaint-and-objecttrust-methods

      puts "********* Start operation for mime_type: #{mime_type.to_s} and tempfile #{f.path} in folder #{Dir.pwd}*************"

      if [:PDF].include?(mime_type) then

        check_program('convert'); check_program('abbyyocr')
        puts "------------ Start pdf convertion: Source: '#{f.path}' Target: '#{f.path+'.conv'}'----------"

        result_sjpg = convert_sjpg(f)
        result_jpg = convert_jpg(f)

        puts "Start abbyyocr..."
        command="abbyyocr -fm -rl German GermanNewSpelling  -if '#{f.path}' -tet UTF8 -of '#{f.path}.conv.txt'"
        res = %x[#{command}]

        result_txt = read_txt_from_conv_txt(f.untaint)

        puts "Read original file..."
        result_pdf=File.read(f.path.untaint) # original file

        puts "ok"

      elsif [:JPG, :JPG_SCANNED].include?(mime_type) then

        check_program('convert'); check_program('pdftotext'); check_program('abbyyocr')
        puts "------------ Start convertion for pdf or jpg: Source: '#{f.path}' Target: '#{f.path+'.conv'}'----------"

        result_sjpg = convert_sjpg(f)
        result_jpg = convert_jpg(f)

        puts "Start abbyyocr..."
        command="abbyyocr -rl German GermanNewSpelling  -if '#{f.path}'  -f PDF -pem ImageOnText -pfpr original -of '#{f.path}.conv'"
        res = %x[#{command}]

        result_pdf=File.read(f.path.untaint+'.conv')
        puts "ok with res: #{res}"

        puts "Start pdftotxt..."
        ## Extract text data and store in database
        res=%x[pdftotext -layout '#{f.path+'.conv'}' #{f.path+'.conv.txt'}]
        result_txt = read_txt_from_conv_txt(f)

      elsif [:MS_EXCEL, :MS_WORD, :ODF_CALC, :ODF_WRITER].include?(mime_type) then

        check_program('convert'); check_program('html2ps'); check_program('tika-app-1.4.jar') ##jar can be called directly

        ############### Create Preview Pictures of uploaded file

        puts "------------ Start convertion for pdf or jpg: Source: '#{f.path}' ----------"

        ## Tika ############################### http://tika.apache.org/
        puts "Start Tika Conversion..."
        command="tika-app-1.4.jar -h '#{f.path}' >> #{f.path+'.conv.html'}"
        res=%x[#{command}]
        puts "ok, Result: #{res}"

        puts "Start converting to pre-jpg original size..."
        res=%x[convert '#{f.path+'.conv.html'}'[0] jpg:'#{f.path+'.conv.tmp'}'] #convert only first page if more exists
        puts "ok"

        result_sjpg = convert_sjpg(f, '.conv.tmp')
        result_jpg = convert_jpg(f, '.conv.tmp')

        ################ Extract Test from uploaded file

        puts "Start tika to extract text..."
        res=%x[tika-app-1.4.jar -t '#{f.path}' >> #{f.path+'.conv.txt'}]

        result_txt = read_txt_from_conv_txt(f)
        result_pdf=nil

      else
        raise "Unkonw mime -type  *#{mime_type}*"
      end

      puts "Clean-up with: #{f.path+'*'}..."
                #### Cleanup and return
      Dir.glob(f.path+'*').each do |l|
        l.untaint
        File.delete(l)
      end
      puts "ok"
      puts "--------- Completed and  file deleted------------"
      return result_jpg, result_sjpg, result_pdf, result_txt, 'OK'

    rescue Exception => e
      puts "Error:"+ e.message
      return nil, nil, nil, nil, "Error:"+ e.message
    end
  end

  def read_txt_from_conv_txt(f)
    puts "    start reading textfile"
    result_txt=''
    File.open(f.path+'.conv.txt', 'r') { |l| result_txt=l.read }
    puts "ok"
    return result_txt
  end

  def convert_jpg(f, source_extension='')
    puts "Start converting to jpg..."
    res=%x[convert '#{f.path+source_extension}'[0] -flatten -resize x770 jpg:'#{f.path+'.conv'}'] #convert only first page if more exists
    result_jpg=File.read(f.path+'.conv')
    puts "ok"
    result_jpg
  end

  def convert_sjpg(f, source_extension='')
    puts "Start converting to sjpg..."
    res=%x[convert '#{f.path+source_extension}'[0] -flatten -resize 350x490\! jpg:'#{f.path+'.conv'}'] #convert only first page if more exists
    result_sjpg=File.read(f.path+'.conv')
    puts "ok"
    result_sjpg
  end

  private :read_txt_from_conv_txt, :convert_jpg, :convert_sjpg
end