# frozen_string_literal: true

module UidGenerator
  extend ActiveSupport::Concern

  included do
    before_create :generate_uid
  end

  def generate_uid
    self.uid = SecureRandom.uuid if uid.blank?
  end
end
