# frozen_string_literal: true

# Payment webhook bodies carry the payment object (customer and card details) under "content".
# Keep it out of the request log; event_id and event_type stay visible.
Rails.application.config.filter_parameters += [/\Acontent\z/]
