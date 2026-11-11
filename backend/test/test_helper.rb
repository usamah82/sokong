ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # A locality counts as staffed when a real account is linked. The account
    # foreign key rejects the placeholder ids these examples used before accounts existed.
    def link_account(locality)
      account = Account.register!(
        email: "staff-#{SecureRandom.hex(8)}@example.com",
        password: "correct horse battery staple"
      )
      LocalityAssignment.create!(account:, locality:)
    end
  end
end
