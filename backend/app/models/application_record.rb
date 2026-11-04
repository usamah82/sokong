class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  self.implicit_order_column = :created_at

  before_create :assign_uuid

  private
    def assign_uuid
      self.id ||= SecureRandom.uuid
    end
end
