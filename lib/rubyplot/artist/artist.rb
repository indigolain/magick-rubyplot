module Rubyplot
  class Artist
    include Magick

    # Writes the plot to a file. Defaults to 'plot.png'
    # Example:
    #   write('graphs/scatter_plot.png')
    def write(filename = 'plot.png')
      draw

      @base_image.write(filename)
    end

    protected

    # Basic Rendering function that takes pre-processed input and plots it on
    # a figure canvas. This function only contains the generalized layout of a
    # plot. Based on individual cases the actual drawing function of a plot will
    # use super to call this method. And then draw upon the figure canvas.
    def draw
      return unless @has_data
      setup_drawing
      draw_legend
      draw_line_markers
      draw_title
      draw_axis_labels
    end

    # Calculates size of drawable area and generates normalized data.
    #
    # * line markers
    # * legend
    # * title
    def setup_drawing
      calculate_spread
      normalize
      setup_graph_measurements
    end

    ##
    # Calculates size of drawable area, general font dimensions, etc.
    # This is the most crucial part of the code and is based on geometry.
    # It calcuates the measurments in pixels to figure out the positioning
    # gap pixels of Legends, Labels and Titles.
    def setup_graph_measurements
      @marker_caps_height = calculate_caps_height(@marker_font_size)
      print @marker_caps_height, '<- Marker Caps', "\n"
      @title_caps_height = @hide_title || @title.nil? ? 0 :
          calculate_caps_height(@title_font_size) * @title.lines.to_a.size
      # Initially the title is nil.
      print @title_caps_height, '<- title_caps_height ', "\n"

      @legend_caps_height = calculate_caps_height(@legend_font_size)
      print @legend_caps_height, '<- legend_caps_height ', "\n"
      # For Now the labels feature only focuses on the dot graph so it makes sense to only have
      # this as an attribute for this kind of graph and not for others.
      if @has_left_labels
        longest_left_label_width = calculate_width(@marker_font_size,
                                                   labels.values.inject('') { |value, memo| value.to_s.length > memo.to_s.length ? value : memo }) * 1.25
      else
        longest_left_label_width = calculate_width(@marker_font_size,
                                                   label(@maximum_value.to_f, @increment))
      end
      print longest_left_label_width, '<- longest_left_label_width', "\n"

      # Shift graph if left line numbers are hidden
      line_number_width = @hide_line_numbers && !@has_left_labels ?
          0.0 :
          (longest_left_label_width + LABEL_MARGIN * 2)

      @graph_left = @left_margin +
                    line_number_width +
                    (@y_axis_label.nil? ? 0.0 : @marker_caps_height + LABEL_MARGIN * 2)
      print @graph_left, '<- graph_left', "\n"

      # Make space for half the width of the rightmost column label.
      last_label = @labels.keys.max.to_i
      extra_room_for_long_label = last_label >= (@column_count - 1) && @center_labels_over_point ?
          calculate_width(@marker_font_size, @labels[last_label]) / 2.0 : 0
      @graph_right_margin = @right_margin + extra_room_for_long_label

      @graph_bottom_margin = @bottom_margin + @marker_caps_height + LABEL_MARGIN

      @graph_right = @raw_columns - @graph_right_margin
      @graph_width = @raw_columns - @graph_left - @graph_right_margin

      # When @hide title, leave a title_margin space for aesthetics.
      @graph_top = @legend_at_bottom ? @top_margin : (@top_margin +
          (@hide_title ? title_margin : @title_caps_height + title_margin) +
          (@legend_caps_height + legend_margin))

      x_axis_label_height = @x_axis_label.nil? ? 0.0 :
          @marker_caps_height + LABEL_MARGIN
      @graph_bottom = @raw_rows - @graph_bottom_margin - x_axis_label_height - @label_stagger_height
      @graph_height = @graph_bottom - @graph_top
    end

    # Draw the optional labels for the x axis and y axis.
    def draw_axis_labels
      unless @x_axis_label.nil?
        # X Axis
        # Centered vertically and horizontally by setting the
        # height to 1.0 and the width to the width of the graph.
        x_axis_label_y_coordinate = @graph_bottom + LABEL_MARGIN * 2 + @marker_caps_height

        # TODO: Center between graph area
        @d.fill = @font_color
        @d.font = @font if @font
        @d.stroke('transparent')
        @d.pointsize = scale_fontsize(@marker_font_size)
        @d.gravity = NorthGravity
        @d = @d.scale_annotation(@base_image,
                                 @raw_columns, 1.0,
                                 0.0, x_axis_label_y_coordinate,
                                 @x_axis_label, @scale)
      end

      unless @y_axis_label.nil?
        # Y Axis, rotated vertically
        @d.rotation = -90.0
        @d.gravity = CenterGravity
        @d = @d.scale_annotation(@base_image,
                                 1.0, @raw_rows,
                                 @left_margin + @marker_caps_height / 2.0, 0.0,
                                 @y_axis_label, @scale)
        @d.rotation = 90.0
      end
    end

    ##
    # Draws a legend with the names of the datasets matched
    # to the colors used to draw them.
    def draw_legend
      @legend_labels = @data.collect { |item| item[DATA_LABEL_INDEX] }

      legend_square_width = @legend_box_size # small square with color of this item

      # May fix legend drawing problem at small sizes
      @d.font = @font if @font
      @d.pointsize = @legend_font_size

      label_widths = [[]] # Used to calculate line wrap
      @legend_labels.each do |label|
        metrics = @d.get_type_metrics(@base_image, label.to_s)
        label_width = metrics.width + legend_square_width * 2.7
        label_widths.last.push label_width

        if sum(label_widths.last) > (@raw_columns * 0.9)
          label_widths.push [label_widths.last.pop]
        end
      end

      current_x_offset = center(sum(label_widths.first))
      current_y_offset = @legend_at_bottom ? @graph_height + title_margin : (@hide_title ?
          @top_margin + title_margin :
          @top_margin + title_margin + @title_caps_height)

      @legend_labels.each_with_index do |legend_label, _index|
        # Draw label
        @d.fill = @font_color
        @d.font = @font if @font
        @d.pointsize = scale_fontsize(@legend_font_size) # font size in points
        @d.stroke('transparent')
        @d.font_weight = NormalWeight
        @d.gravity = WestGravity
        @d = @d.scale_annotation(@base_image,
                                 @raw_columns, 1.0,
                                 current_x_offset + (legend_square_width * 1.7), current_y_offset,
                                 legend_label.to_s, @scale)

        # Now draw box with color of this dataset
        @d = @d.stroke('transparent')
        @d = @d.fill('black')
        @d = @d.rectangle(current_x_offset,
                          current_y_offset - legend_square_width / 2.0,
                          current_x_offset + legend_square_width,
                          current_y_offset + legend_square_width / 2.0)
        # string = 'hello' + _index.to_s + '.png'
        # @base_image.write(string)

        @d.pointsize = @legend_font_size
        metrics = @d.get_type_metrics(@base_image, legend_label.to_s)
        current_string_offset = metrics.width + (legend_square_width * 2.7)

        # Handle wrapping
        label_widths.first.shift
        if label_widths.first.empty?

          label_widths.shift
          current_x_offset = center(sum(label_widths.first)) unless label_widths.empty?
          line_height = [@legend_caps_height, legend_square_width].max + legend_margin
          unless label_widths.empty?
            # Wrap to next line and shrink available graph dimensions
            current_y_offset += line_height
            @graph_top += line_height
            @graph_height = @graph_bottom - @graph_top
          end
        else
          current_x_offset += current_string_offset
        end
      end
      @color_index = 0
    end

    # Use with a theme definition method to draw a gradiated background.
    def render_gradiated_background(top_color, _bottom_color, _direct = :top_bottom)
      gradient_fill = GradientFill.new(0, 0, 100, 0, '#FF6A6A', top_color)
      Image.new(@columns, @rows, gradient_fill)
    end

    # Draws a title on the graph.
    def draw_title
      return if @hide_title || @title.nil?

      @d.fill = @font_color
      @d.font = @title_font || @font if @title_font || @font
      @d.stroke('transparent')
      @d.pointsize = scale_fontsize(@title_font_size)
      @d.font_weight = @bold_title ? BoldWeight : NormalWeight
      @d.gravity = NorthGravity
      @d = @d.annotate_scaled(@base_image,
                              @raw_columns, 1.0,
                              0, @top_margin,
                              @title, @scale)
    end

    private

    # Return a formatted string representing a number value that should be
    # printed as a label.
    def label(value, increment)
      label = if increment
                if increment >= 10 || (increment * 1) == (increment * 1).to_i.to_f
                  format('%0i', value)
                elsif increment >= 1.0 || (increment * 10) == (increment * 10).to_i.to_f
                  format('%0.1f', value)
                elsif increment >= 0.1 || (increment * 100) == (increment * 100).to_i.to_f
                  format('%0.2f', value)
                elsif increment >= 0.01 || (increment * 1000) == (increment * 1000).to_i.to_f
                  format('%0.3f', value)
                elsif increment >= 0.001 || (increment * 10_000) == (increment * 10_000).to_i.to_f
                  format('%0.4f', value)
                else
                  value.to_s
                end
              elsif (@spread.to_f % (@marker_count.to_f == 0 ? 1 : @marker_count.to_f) == 0) || !@y_axis_increment.nil?
                value.to_i.to_s
              elsif @spread > 10.0
                format('%0i', value)
              elsif @spread >= 3.0
                format('%0.2f', value)
              else
                value.to_s
              end

      parts = label.split('.')
      parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{THOUSAND_SEPARATOR}")
      parts.join('.')
    end
  end
end
