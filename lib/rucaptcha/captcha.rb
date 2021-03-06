require 'open3'

module RuCaptcha
  class Captcha
    class << self
      def random_color
        if RuCaptcha.config.style == :colorful
          color1 = rand(56) + 15
          color2 = rand(10) + 140
          color = [color1, color2, rand(15)]
          color.shuffle!
          color
        else
          color_seed = rand(40) + 10
          [color_seed, color_seed, color_seed]
        end
      end

      def random_chars
        chars = SecureRandom.hex(RuCaptcha.config.len / 2).downcase
        chars.gsub!(/[0ol1]/i, (rand(8) + 2).to_s)
        chars
      end

      def rand_line_top(text_top, font_size)
        text_top + rand(font_size * 0.7).to_i
      end

      # Create Captcha image by code
      def create(code)
        chars        = code.split('')
        all_left     = 20
        font_size    = RuCaptcha.config.font_size
        full_height  = font_size
        full_width   = font_size * chars.size
        size         = "#{full_width}x#{full_height}"
        half_width   = full_width / 2
        text_top     = 0
        text_left    = 0 - (font_size * 0.28).to_i
        stroke_width = 6 # (font_size * 0.05).to_i + 1
        text_width   = font_size + text_left
        text_opts    = []
        line_opts    = []

        rgbs = []
        chars.count.times do |i|
          color = random_color
          if i > 0
            preview_color = rgbs[i - 1]
            # Avoid color same as preview color
            if color.index(color.min) == preview_color.index(preview_color.min) &&
               color.index(color.max) == preview_color.index(preview_color.max)
              # adjust RGB order
              color = [color[1], color[2], color[0]]
            end
          end
          rgbs << color
        end

        chars.each_with_index do |char, i|
          rgb = RuCaptcha.config.style == :colorful ? rgbs[i] : rgbs[0]
          text_color = "rgba(#{rgb.join(',')}, #{RuCaptcha.config.text_color_alpha})"
          line_color = "rgba(#{rgb.join(',')}, #{RuCaptcha.config.line_color_alpha})"
          text_opts << %(-fill '#{text_color}' -draw 'text #{(text_left + text_width) * i + all_left},#{text_top} "#{char}"')
          left_y = rand_line_top(text_top, font_size)
          right_x = half_width + (half_width * 0.3).to_i
          right_y = rand_line_top(text_top, font_size)
          line_opts << %(-draw 'stroke #{line_color} line #{rand(10)},#{left_y} #{right_x},#{right_y}') if line_opts.size < RuCaptcha.config.line_num
        end

        command = <<-CODE
          convert -size #{size} \
          -strokewidth #{stroke_width} \
          #{line_opts.join(' ')} \
          -pointsize #{font_size} -weight 500 \
          #{text_opts.join(' ')}  \
          -wave #{rand(2) + 3}x#{rand(2) + 1} \
          -rotate #{rand(10) - 5} \
          -gravity NorthWest -sketch 1x10+#{rand(2)} \
          -fill none \
          -implode #{RuCaptcha.config.implode} -trim label:- png:-
        CODE

        if Gem.win_platform?
          png_file_path = Rails.root.join('tmp', 'cache', "#{code}.png")
          command = "convert -size #{size} xc:White -gravity Center -weight 12 -pointsize 20 -annotate 0 \"#{code}\" -trim #{png_file_path}"
          out, err, _st = Open3.capture3(command)
          warn "  RuCaptcha #{err.strip}" if err.present?
          png_file_path
        else
          command.strip!
          out, err, _st = Open3.capture3(command)
          warn "  RuCaptcha #{err.strip}" if err.present?
          out
        end
      end

      def warn(msg)
        msg = "  RuCaptcha #{msg}"
        Rails.logger.error(msg)
      end
    end
  end
end
