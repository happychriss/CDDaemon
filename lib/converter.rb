require_relative '../lib/support'

class Converter

  ### this part is running on the remove server (desktop) not on the qnas, should have convert and pdftotext installed

  include Support

  def alive?
    true
  end

  def run_conversion(data, mime_type)

    begin

      f = Tempfile.new("cd2_remote")
      f.write(data)
      f.untaint #avoid ruby insecure operation: http://stackoverflow.com/questions/12165664/what-are-the-rubys-objecttaint-and-objecttrust-methods
      fpath=f.path #full path to the file to be processed

      puts "********* Start operation for mime_type: #{mime_type.to_s} and tempfile #{f.path} in folder #{Dir.pwd}*************"

      if [:PDF].include?(mime_type) then

        check_program('convert'); check_program('abbyyocr')
        puts "------------ Start pdf convertion: Source: '#{fpath}' Target: '#{fpath+'.conv'}'----------"

        result_sjpg = convert_sjpg(fpath)
        result_jpg = convert_jpg(fpath)

        puts "Start abbyyocr..."
        command="abbyyocr -fm -rl German GermanNewSpelling  -if '#{fpath}' -tet UTF8 -of '#{fpath}.conv.txt'"
        res = %x[#{command}]

        result_txt = read_txt_from_conv_txt(fpath.untaint)

        puts "Read original file..."

        result_orginal=data

        puts "ok"

      ### jpgs will be converted into PDF
      elsif [:JPG].include?(mime_type) then


        check_program('convert'); check_program('pdftotext'); check_program('abbyyocr')
        puts "------------ Start conversion for jpg: Source: '#{fpath}' Target: '#{fpath+'.conv'}'----------"


        fopath=fpath+'.orient'
        res=%x[convert '#{fpath}'[0] -auto-orient jpg:'#{fopath}'] #convert only first page if more exists

        result_sjpg = convert_sjpg(fopath)
        result_jpg = convert_jpg(fopath)

        puts "Start abbyyocr..."
        command="abbyyocr -rl German GermanNewSpelling  -if '#{fopath}'  -f PDF -pem ImageOnText -pfpr original -of '#{fpath}.conv'"
        res = %x[#{command}]

        result_orginal=File.read(fpath.untaint+'.conv')   ## PDF return

        puts "ok with res: #{res}"

        puts "Start pdftotxt..."
        ## Extract text data and store in database
        res=%x[pdftotext -layout '#{fpath+'.conv'}' #{fpath+'.conv.txt'}]
        result_txt = read_txt_from_conv_txt(fpath)

      elsif [:MS_EXCEL, :MS_WORD, :ODF_CALC, :ODF_WRITER].include?(mime_type) then

        tika_path=File.join(Dir.pwd,"lib","tika-app-1.4.jar")

        check_program('convert'); check_program('html2ps'); check_program(tika_path) ##jar can be called directly

        ############### Create Preview Pictures of uploaded file

        puts "------------ Start conversion for pdf or jpg: Source: '#{fpath}' ----------"

        ## Tika ############################### http://tika.apache.org/
        puts "Start Tika Conversion..."
        command="#{tika_path} -h '#{fpath}' >> #{fpath+'.conv.html'}"
        res=%x[#{command}]
        puts "ok, Result: #{res}"

        puts "Start converting to pre-jpg original size..."
        res=%x[convert '#{fpath+'.conv.html'}'[0] jpg:'#{fpath+'.conv.tmp'}'] #convert only first page if more exists
        puts "ok"

        result_sjpg = convert_sjpg(fpath, '.conv.tmp')
        result_jpg = convert_jpg(fpath, '.conv.tmp')

        ################ Extract Test from uploaded file

        puts "Start tika to extract text..."
        res=%x[#{tika_path} -t '#{fpath}' >> #{fpath+'.conv.txt'}]

        result_txt = read_txt_from_conv_txt(fpath)

        result_orginal=data

      else
        raise "Unkonw mime -type  *#{mime_type}*"
      end

      puts "Clean-up with: #{fpath+'*'}..."
                #### Cleanup and return
      Dir.glob(fpath+'*').each do |l|
        l.untaint
        File.delete(l)
      end
      puts "ok"
      puts "--------- Completed and  file deleted------------"
      return result_jpg, result_sjpg, result_orginal,result_txt, 'OK'

    rescue Exception => e
      puts "Error:"+ e.message
      return nil, nil, nil, nil, "Error:"+ e.message
    end
  end

  def read_txt_from_conv_txt(fpath)
    puts "    start reading textfile"
    result_txt=''
    File.open(fpath+'.conv.txt', 'r') { |l| result_txt=l.read }
    puts "ok"
    return result_txt
  end

  def convert_jpg(fpath, source_extension='')
    puts "Start converting to jpg..."
    res=%x[convert '#{fpath+source_extension}'[0]   -flatten -resize x770 jpg:'#{fpath+'.conv'}'] #convert only first page if more exists
    result_jpg=File.read(fpath+'.conv')
    puts "ok"
    result_jpg
  end

  def convert_sjpg(fpath, source_extension='')
    puts "Start converting to sjpg..."
    res=%x[convert '#{fpath+source_extension}'[0]  -flatten -resize 350x490\! jpg:'#{fpath+'.conv'}'] #convert only first page if more exists
    result_sjpg=File.read(fpath+'.conv')
    puts "ok"
    result_sjpg
  end

  private :read_txt_from_conv_txt, :convert_jpg, :convert_sjpg
end