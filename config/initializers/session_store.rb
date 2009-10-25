# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_compiler_session',
  :secret      => 'accd5ce381e0f0f228d505d580b1104c339bb55fd13107db49472747b1c2bfe72cd5b37215bfac2d6a3b06a1081eb3cc78d670b8e6d1fb0d339f4f32233490a9'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
