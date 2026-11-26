module Research
  module Sections
    module_function

    # One-based half-open spans, matching LineEdit. Selectors are local to
    # the document revision. Heading text is display data and may repeat.
    def prose_lines(lines)
      fence = nil
      lines.each_with_index do |line, index|
        if fence
          fence = nil if line.chomp.match?(/\A {0,3}#{Regexp.escape(fence[0])}{#{fence.size},}[ \t]*\z/)
          next
        end
        if (opening = line.match(/\A {0,3}(`{3,}|~{3,})(.*)$/))
          fence = opening[1] unless opening[1][0] == '`' && opening[2].include?('`')
          next
        end
        yield line, index
      end
    end

    def outline(text)
      lines = LineEdit.lines(text)
      entries = []
      parents = []
      prose_lines(lines) do |line, index|
        heading = line.chomp.match(/\A {0,3}(\#{1,6})(?:[ \t]+(.*)|$)/)
        next unless heading

        depth = heading[1].size
        title = heading[2].to_s.sub(/(?:\A|[ \t]+)\#+[ \t]*\z/, '').strip
        number = index + 1
        while parents.last && parents.last['depth'] >= depth
          parents.pop['end_line'] = number
        end
        entry = { 'selector' => "L#{number}", 'title' => title, 'depth' => depth,
                  'path' => parents.map { |p| p['title'] } + [title],
                  'start_line' => number, 'end_line' => lines.size + 1 }
        entries << entry
        parents << entry
      end
      entries
    end

    def select!(entries, selector)
      entries.find { |e| e['selector'] == selector } ||
        raise(ParameterException, "Unknown section #{selector.inspect}; read the document outline")
    end

    # One-based, half-open. The direct body ends at the next heading,
    # whether it opens a child or closes the selected section.
    def body_span(rows, section)
      heading = section.fetch('start_line')
      following = rows.find { |row| row['start_line'] > heading }
      [heading + 1, following ? following['start_line'] : section.fetch('end_line')]
    end

    def edit(text, mode, selector, content)
      rows = outline(text)
      section = select!(rows, selector) if selector
      lines = LineEdit.lines(text)
      # Scout can normalize an explicitly empty string to nil. Accept that
      # form only when it leaves an already empty body untouched.
      if content.nil? && mode == 'replace_section' && section
        first, last = body_span(rows, section)
        return text if first == last
        raise ParameterException, 'replace_section requires content for a nonempty body; use delete_lines to clear it'
      end
      additions = outline(content)
      if mode == 'add_section'
        first = additions.first
        unless first && first['start_line'] == 1 && first['end_line'] == LineEdit.count(content) + 1 &&
               (!section || first['depth'] == section['depth'] + 1)
          raise ParameterException, 'content must begin with one ATX section, one level below its parent when supplied'
        end
        at = section ? section['end_line'] - 1 : lines.length
        if !section && rows.any? && first['depth'] > rows.map { |row| row['depth'] }.min
          raise ParameterException, 'choose a parent to append a nested section'
        end
        finish = at
      else
        raise ParameterException, 'replace_section requires a section selector' unless section
        raise ParameterException, 'replace_section edits the body; use add_section for headings' unless additions.empty?
        first, last = body_span(rows, section)
        at = first - 1
        finish = last - 1
        return text if lines[at...finish].join == content
      end

      before = lines.take(at).join
      after = lines.drop(finish).join
      newline = before.scan(/\r?\n/).last || text[/\r?\n/] || content[/\r?\n/] || "\n"
      before << newline unless before.empty? || before.end_with?("\n")
      insert = content.dup
      if mode == 'add_section' && !before.empty? && !before.lines.last.strip.empty?
        before << newline
      end
      insert << newline unless after.empty? || insert.empty? || insert.end_with?("\n")
      if mode == 'add_section' && !after.empty? &&
         !after.lines.first.strip.empty? && !insert.lines.last.strip.empty?
        insert << newline
      end
      result = before + insert + after
      # A dangling fence could hide following headings, or hide a new section.
      unless outline(result).size == rows.size + additions.size
        raise ParameterException, 'section boundary is inside an unclosed Markdown fence'
      end
      result
    end
  end
end
