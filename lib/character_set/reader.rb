class CharacterSet < SortedSet
  module Reader
    module_function

    def codepoints_from_enumerable(object)
      raise ArgumentError, 'pass an Enumerable' unless object.is_a?(Enumerable)
      object.each do |el|
        return object            if el.is_a?(Integer) && el <= 0x10FFFF
        return object.map(&:ord) if el.is_a?(String)  && el.length == 1
        raise ArgumentError, "#{el.inspect} is not valid as a codepoint"
      end
    end

    def codepoints_from_bracket_expression(string)
      raise ArgumentError, 'pass a String'   unless string.is_a?(String)
      raise ArgumentError, 'advanced syntax' if string =~ /\\[^uUx]|[^\\]\[|&&/

      content = strip_brackets(string)
      literal_content = eval_escapes(content)

      prev_chr = nil
      in_range = false

      literal_content.each_char.map do |chr|
        if chr == '-' && prev_chr && prev_chr != '\\' && prev_chr != '-'
          in_range = true
          nil
        else
          result = in_range ? ((prev_chr.ord + 1)..(chr.ord)).to_a : chr.ord
          in_range = false
          prev_chr = chr
          result
        end
      end.compact.flatten
    end

    def strip_brackets(string)
      string[/\A\[\^?(.*)\]\z/, 1] || string.dup
    end

    def eval_escapes(string)
      string.gsub(/\\U(\h{8})|\\u(\h{4})|U\+(\h+)|\\x(\h{2})|\\u\{(\h+)\}/) do
        ($1 || $2 || $3 || $4 || $5).to_i(16).chr('utf-8')
      end
    end
  end
end
