namespace :sokong do
  desc "Create a confirmed community worker. EMAIL, NAME, and PASSWORD are required."
  task worker: :environment do
    email = ENV["EMAIL"].to_s.strip
    name = ENV["NAME"].to_s.strip
    password = ENV.fetch("PASSWORD", "")
    abort "EMAIL, NAME, and PASSWORD are required" if email.empty? || name.empty? || password.empty?
    abort "PASSWORD is too short" if password.length < 12
    abort "EMAIL has already been taken" if Account.exists?(email_normalized: email.downcase(:fold))

    Account.create!(
      email: email,
      name: name,
      password: password,
      role: "worker",
      email_confirmed_at: Time.current
    )
  end

  desc "Create a locality and print its id. NAME is required."
  task locality: :environment do
    name = ENV["NAME"].to_s.strip.gsub(/\s+/, " ")
    abort "NAME is required" if name.empty?
    abort "NAME is too long" if name.length > 200

    puts Locality.create!(name: name).id
  end

  desc "Link an account to a locality. EMAIL and LOCALITY_ID are required."
  task assign: :environment do
    account = Account.find_by(email_normalized: ENV["EMAIL"].to_s.strip.downcase(:fold))
    locality = Locality.find_by(id: ENV["LOCALITY_ID"].to_s.strip)
    abort "EMAIL is unknown" unless account
    abort "LOCALITY_ID is unknown" unless locality

    LocalityAssignment.find_or_create_by!(account: account, locality: locality)
  end
end
