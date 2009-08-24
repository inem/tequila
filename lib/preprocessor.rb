module TequilaPreprocessor
  EOB = "end\n".freeze
  EOC = "end\n".freeze
  JAZZ = ".jazz".freeze
  def TequilaPreprocessor.run(source, offset = -1)
    source = replace(source)
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
    (prev - offset).times { text += EOB }
    text
  end
private
  def TequilaPreprocessor.replace(source)
    text = ''
    while (i = (/(^ *)&(.*$)/ =~ source)) do
      text += source[0...i]
      source = $'
      spaces = $1.size
      filename = $2 + ".jazz"
      text += include_file(filename, spaces)
    end
    text += source
  end

  def TequilaPreprocessor.include_file(filename, offset)
    lines = ''
    prefix = ' ' * offset
    f = open(filename, 'r')
    while (s = f.gets) do
      lines << prefix + s
    end
    f.close
    lines
  end
  def TequilaPreprocessor.spaces(line)
    (/^ +/ =~ line) ? [$&.size, $'] : [0, line]
  end
end

