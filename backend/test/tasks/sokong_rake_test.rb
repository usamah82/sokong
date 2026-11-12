require "test_helper"
require "rake"

class SokongRakeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    %w[EMAIL NAME PASSWORD LOCALITY_ID].each { |key| ENV.delete(key) }
  end

  test "sokong:worker creates a confirmed worker and queues no mail" do
    assert_no_enqueued_jobs do
      assert_difference "Account.count", 1 do
        invoke("sokong:worker", "EMAIL" => "Aman@Example.com", "NAME" => "Aman", "PASSWORD" => "a long passphrase")
      end
    end

    account = Account.find_by!(email_normalized: "aman@example.com")
    assert_equal "worker", account.role
    assert_equal "Aman", account.name
    assert_not_nil account.email_confirmed_at
    assert account.authenticate("a long passphrase")
    assert_equal 0, ActionMailer::Base.deliveries.size

    post_accounts = Rails.application.routes.routes.map { |route| "#{route.verb} #{route.path.spec}" }
    assert_not post_accounts.any? { |route| route.match?(%r{worker|assign}) }
  end

  test "a duplicate email or a short password creates nothing" do
    invoke("sokong:worker", "EMAIL" => "aman@example.com", "NAME" => "Aman", "PASSWORD" => "a long passphrase")
    digest = Account.last.password_digest

    assert_no_difference "Account.count" do
      error = assert_raises(SystemExit) do
        invoke("sokong:worker", "EMAIL" => "AMAN@example.com", "NAME" => "Other", "PASSWORD" => "another long passphrase")
      end
      assert_equal 1, error.status
    end
    assert_equal digest, Account.last.password_digest
    assert_equal "Aman", Account.last.name

    assert_no_difference "Account.count" do
      assert_raises(SystemExit) do
        invoke("sokong:worker", "EMAIL" => "new@example.com", "NAME" => "New", "PASSWORD" => "short")
      end
    end
  end

  test "sokong:locality prints an id and sokong:assign links it once" do
    invoke("sokong:worker", "EMAIL" => "aman@example.com", "NAME" => "Aman", "PASSWORD" => "a long passphrase")
    output = invoke("sokong:locality", "NAME" => "Block 4")
    locality_id = output.strip
    assert_equal locality_id, Locality.find_by!(name: "Block 4").id

    assert_difference "LocalityAssignment.count", 1 do
      invoke("sokong:assign", "EMAIL" => "Aman@Example.com", "LOCALITY_ID" => locality_id)
    end
    assert_no_difference "LocalityAssignment.count" do
      invoke("sokong:assign", "EMAIL" => "aman@example.com", "LOCALITY_ID" => locality_id)
    end
    assert_equal 1, LocalityAssignment.count
  end

  test "an unknown email or an unknown locality fails and creates no link" do
    locality = Locality.create!(name: "Block 4")

    assert_no_difference "LocalityAssignment.count" do
      assert_raises(SystemExit) do
        invoke("sokong:assign", "EMAIL" => "missing@example.com", "LOCALITY_ID" => locality.id)
      end
      assert_raises(SystemExit) do
        invoke("sokong:assign", "EMAIL" => "aman@example.com", "LOCALITY_ID" => SecureRandom.uuid)
      end
    end
  end

  private
    def invoke(name, env)
      env.each { |key, value| ENV[key] = value }
      output, = capture_io { Rake::Task[name].invoke }
      output
    ensure
      Rake::Task[name].reenable
      env.each_key { |key| ENV.delete(key) }
    end
end
