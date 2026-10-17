# frozen_string_literal: true

module Tax
  module SortHelper
    def tax_sort_link(label, column:, sort:, direction:, base_params:, path:, align: :left, data: {})
      next_direction = SortParams.next_direction(sort, column, direction)
      merged = base_params.symbolize_keys.merge(sort: column, direction: next_direction)
      url = send(path, **merged)

      active = sort == column
      align_class = { left: "text-left", right: "text-right", center: "text-center" }.fetch(align, "text-left")

      link_to url, class: class_names(
        "inline-flex items-center gap-1 hover:text-primary font-medium",
        align_class,
        ("text-primary" if active)
      ), data: data do
        safe_join([
          label,
          (active ? icon(direction == "desc" ? "chevron-down" : "chevron-up", class: "w-3 h-3 shrink-0") : nil)
        ].compact)
      end
    end
  end
end
