# frozen_string_literal: true

module Pdf
  class BaseGenerator
    BRAND_COLOR  = '4F46E5'
    ACCENT_COLOR = '818CF8'
    MUTED_COLOR  = '6B7280'
    TEXT_COLOR    = '111827'
    LIGHT_BG     = 'F3F4F6'
    BORDER_COLOR = 'E5E7EB'
    WHITE        = 'FFFFFF'

    def initialize(options = {})
      @document = Prawn::Document.new(
        page_size: options.fetch(:page_size, 'A4'),
        margin: options.fetch(:margin, 40)
      )
    end

    def render
      build_content
      apply_footer
      @document.render
    end

    private

    def build_content
      raise NotImplementedError, "#{self.class} must implement #build_content"
    end

    def header(title, subtitle = nil)
      @document.fill_color BRAND_COLOR
      @document.fill_rectangle [0, @document.cursor + 8], @document.bounds.width, 4
      @document.move_down 16

      @document.fill_color MUTED_COLOR
      @document.font_size(9) do
        @document.text 'SHUTTLE OFFICE', character_spacing: 3, style: :bold
      end
      @document.move_down 8

      @document.fill_color TEXT_COLOR
      @document.font_size(22) do
        @document.text title, style: :bold
      end

      if subtitle
        @document.move_down 4
        @document.fill_color MUTED_COLOR
        @document.font_size(9) { @document.text subtitle }
      end

      @document.move_down 20
      reset_colors
    end

    def section(title)
      @document.fill_color BRAND_COLOR
      @document.font_size(8) do
        @document.text title.upcase, style: :bold, character_spacing: 2
      end
      @document.move_down 10
      reset_colors

      yield if block_given?

      @document.move_down 6
      divider
      @document.move_down 16
    end

    def info_row(label, value)
      y_position = @document.cursor
      @document.fill_color MUTED_COLOR
      @document.font_size(9) do
        @document.text_box label,
          at: [0, y_position],
          width: 160,
          height: 14
      end
      @document.fill_color TEXT_COLOR
      @document.font_size(10) do
        @document.text_box value.to_s,
          at: [160, y_position],
          width: @document.bounds.width - 160,
          height: 14,
          style: :bold
      end
      @document.move_down 18
    end

    def divider
      @document.stroke_color BORDER_COLOR
      @document.line_width 0.5
      @document.stroke_horizontal_rule
      @document.stroke_color '000000'
      @document.line_width 1
    end

    def apply_footer
      @document.repeat(:all) do
        @document.bounding_box([0, 28], width: @document.bounds.width, height: 20) do
          @document.fill_color MUTED_COLOR
          @document.font_size(7) do
            @document.text_box(
              "Generated #{Time.current.strftime('%B %d, %Y at %H:%M')} | Shuttle Office",
              at: [0, 12],
              width: @document.bounds.width - 60
            )
            @document.text_box(
              "Page #{@document.page_number}",
              at: [0, 12],
              width: @document.bounds.width,
              align: :right
            )
          end
          @document.fill_color TEXT_COLOR
        end
      end
    end

    def reset_colors
      @document.fill_color TEXT_COLOR
      @document.stroke_color '000000'
    end
  end
end
