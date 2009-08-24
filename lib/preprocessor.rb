module TequilaPreprocessor
  EOB = "end\n".freeze
  EOC = "end\n".freeze
  JAZZ = ".jazz".freeze
  
  def TequilaPreprocessor.run(source)
    rrun(source)[0]
  end

  def TequilaPreprocessor.rrun(source, offset = -1)
    prev = offset
    text = ""
    code = nil
    lines = source.split("\n")
    for line in lines do
      spaces, rest = spaces(line)
      raise "#{spaces} spaces in line <#{line}>" if (spaces & 1 != 0)
      tabs = spaces >> 1
      if code
        if tabs <= code
          code = nil
          text += EOC
        else
          text += "#{line}\n"
          next
        end
      end
      case rest
      when /^&(\w+)/
        begin
          txt, tbs = rrun(include_file('_' + $1 + JAZZ, tabs), tabs)
          text += txt
        rescue Errno::ENOENT => e
          p e
        end
        next
      when /^:code/
        code = tabs
      when /^(\+|\-|\<)/
        diff = prev - tabs
        diff += 1 if diff >= 0
        diff.times { text += EOB }
        prev = tabs
      end
      text += "#{line}\n"
    end
    text += EOC if code
    #(prev - offset).times { text += EOB }
    [text, prev - offset]
  end
private
  def TequilaPreprocessor.include_file(filename, offset)
    lines = []
    prefix = '  ' * offset
    f = open(filename, 'r')
    while (s = f.gets) do
      lines << prefix + s.chop
    end
    f.close
    lines
  end
  def TequilaPreprocessor.spaces(line)
    (/^ +/ =~ line) ? [$&.size, $'] : [0, line]
  end
end

